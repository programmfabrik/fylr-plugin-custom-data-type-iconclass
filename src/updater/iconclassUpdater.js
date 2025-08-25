const fs = require('fs')
const https = require('https')
const fetch = (...args) => import('node-fetch').then(({
    default: fetch
}) => fetch(...args));

let databaseLanguages = [];
let frontendLanguages = [];
let defaultLanguage = 'de';

let info = {}

let access_token = '';

if (process.argv.length >= 3) {
    info = JSON.parse(process.argv[2])
}

function hasChanges(objectOne, objectTwo) {
    var len;
    const ref = ["conceptName", "conceptURI", "conceptSource", "_standard", "_fulltext", "conceptAncestors", "frontendLanguage"];
    for (let i = 0, len = ref.length; i < len; i++) {
        let key = ref[i];
        if (!IconclassUtil.isEqual(objectOne[key], objectTwo[key])) {
            return true;
        }
    }
    return false;
}

function getConfigFromAPI() {
    return new Promise((resolve, reject) => {
        var url = 'http://fylr.localhost:8081/api/v1/config?access_token=' + access_token
        fetch(url, {
            headers: {
                'Accept': 'application/json'
            },
        })
            .then(response => {
                if (response.ok) {
                    resolve(response.json());
                } else {
                    console.error("DANTE-Updater: Fehler bei der Anfrage an /config ");
                }
            })
            .catch(error => {
                console.error(error);
                console.error("DANTE-Updater: Fehler bei der Anfrage an /config");
            });
    });
}

function isInTimeRange(currentHour, fromHour, toHour) {
    if (fromHour === toHour) {
        return true;
    }

    if (fromHour < toHour) { // same day
        return currentHour >= fromHour && currentHour < toHour;
    } else { // through the night
        return currentHour >= fromHour || currentHour < toHour;
    }
}

main = (payload) => {
    switch (payload.action) {
        case "start_update":
            outputData({
                "state": {
                    "personal": 2
                },
                "log": ["started logging"]
            })
            break
        case "update":

            ////////////////////////////////////////////////////////////////////////////
            // run iconclass-api-call for every given uri
            ////////////////////////////////////////////////////////////////////////////

            // collect URIs
            let URIList = [];
            for (var i = 0; i < payload.objects.length; i++) {
                URIList.push(payload.objects[i].data.conceptURI);
            }
            // unique urilist
            URIList = [...new Set(URIList)]

            let requestUrls = [];
            let requests = [];

            URIList.forEach((uri) => {
                let dataRequestUrl = uri + '.json'
                let dataRequest = fetch(dataRequestUrl);
                requests.push({
                    url: dataRequestUrl,
                    uri: uri,
                    request: dataRequest
                });
                requestUrls.push(dataRequest);
            });

            Promise.all(requestUrls).then(function (responses) {
                let results = [];
                // Get a JSON object from each of the responses
                responses.forEach((response, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let result = {
                        url: url,
                        uri: uri,
                        data: null,
                        error: null
                    };
                    if (response.ok) {
                        result.data = response.json();
                    } else {
                        result.error = "Error fetching data from " + url + ": " + response.status + " " + response.statusText;
                    }
                    results.push(result);
                });
                return Promise.all(results.map(result => result.data));
            }).then(function (data) {
                let results = [];
                data.forEach((data, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let result = {
                        url: url,
                        uri: uri,
                        data: data,
                        error: null
                    };
                    if (data instanceof Error) {
                        result.error = "Error parsing data from " + url + ": " + data.message;
                    }
                    results.push(result);
                });

                // build cdata from all api-request-results
                let cdataList = [];
                payload.objects.forEach((result, index) => {
                    let originalCdata = payload.objects[index].data;
                    let newCdata = {};
                    let originalURI = originalCdata.conceptURI;

                    const matchingRecordData = results.find(record => record.uri === originalURI);

                    if (matchingRecordData) {
                        // rematch uri, because maybe uri changed / rewrites ..
                        let uri = matchingRecordData.uri;

                        ///////////////////////////////////////////////////////
                        // conceptName, conceptURI, _standard, _fulltext, facet, frontendLanguage
                        data = matchingRecordData.data;
                        if (data) {
                            // get desired language for preflabel. This is frontendlanguage from original data...
                            let desiredLanguage = defaultLanguage;
                            if (originalCdata?.frontendLanguage?.length == 2) {
                                desiredLanguage = originalCdata.frontendLanguage;
                            }
                            // save conceptName
                            newCdata.conceptName = data.prefLabel;

                            // conceptName
                            // change only, if a frontendLanguage is set AND it is not a manually chosen label
                            if (originalCdata?.frontendLanguage?.length == 2) {
                                if (originalCdata?.conceptNameChosenByHand == false || !originalCdata.hasOwnProperty('conceptNameChosenByHand')) {
                                    newCdata.conceptNameChosenByHand = false;
                                    if (data['txt']) {
                                        // if a preflabel exists in given frontendLanguage or without language (person / corporate)
                                        if (data['txt'][originalCdata.frontendLanguage]) {
                                            newCdata.conceptName = data['txt'][originalCdata.frontendLanguage];
                                        }
                                    }
                                }
                            }

                            // if no conceptName is given yet (f.e. via scripted imports..)
                            //   --> choose a label and prefer the configured default language
                            if (!newCdata?.conceptName) {
                                // desiredLanguage exists?
                                if (desiredLanguage) {
                                    if (data['txt']?.[desiredLanguage]) {
                                        newCdata.conceptName = data['txt'][desiredLanguage];
                                    }
                                } else {
                                    if (data.txt?.de) {
                                        newCdata.conceptName = data.txt.de;
                                    } else if (data.txt?.en) {
                                        newCdata.conceptName = data.txt.en;
                                    } else {
                                        newCdata.conceptName = data.txt[Object.keys(data.txt)[0]];
                                    }
                                }
                            }

                            newCdata.conceptName = data.n + ' - ' + newCdata.conceptName;

                            // save conceptURI
                            newCdata.conceptURI = 'https://iconclass.org/' + data.n;

                            // save conceptAncestors
                            newCdata.conceptAncestors = [];
                            let conceptAncestors = [];
                            // if treeview, add ancestors
                            if (data?.p?.length > 0) {
                                // save ancestor-uris to cdata
                                for (let ancestor of data.p) {
                                    conceptAncestors.push('https://iconclass.org/' + ancestor);
                                }
                                // add own uri to ancestor-uris
                                conceptAncestors.push('https://iconclass.org/' + data.n);
                            }
                            let conceptAncestorsString = conceptAncestors.join(' ');
                            newCdata.conceptAncestors = conceptAncestorsString;

                            // save _fulltext
                            newCdata._fulltext = IconclassUtil.getFullTextFromObject(data, databaseLanguages);
                            // save _standard
                            newCdata._standard = IconclassUtil.getStandardTextFromObject(null, data, originalCdata, databaseLanguages);
                            // save facet
                            newCdata.facetTerm = IconclassUtil.getFacetTerm(data, databaseLanguages);

                            // save frontend language (same as given)
                            newCdata.frontendLanguage = desiredLanguage;

                            if (hasChanges(payload.objects[index].data, newCdata)) {
                                payload.objects[index].data = newCdata;
                            } else { }
                        }
                    } else {
                        console.error('No matching record found');
                    }
                });
                outputData({
                    "payload": payload.objects,
                    "log": [payload.objects.length + " objects in payload"]
                });
            });
            // send data back for update
            break;
        case "end_update":
            outputData({
                "state": {
                    "theend": 2,
                    "log": ["done logging"]
                }
            });
            break;
        default:
            outputErr("Unsupported action " + payload.action);
    }
}

outputData = (data) => {
    out = {
        "status_code": 200,
        "body": data
    }
    process.stdout.write(JSON.stringify(out))
    process.exit(0);
}

outputErr = (err2) => {
    let err = {
        "status_code": 400,
        "body": {
            "error": err2.toString()
        }
    }
    console.error(JSON.stringify(err))
    process.stdout.write(JSON.stringify(err))
    process.exit(0);
}

(() => {

    let data = ""

    process.stdin.setEncoding('utf8');

    ////////////////////////////////////////////////////////////////////////////
    // check if hour-restriction is set
    ////////////////////////////////////////////////////////////////////////////

    if (info?.config?.plugin?.['custom-data-type-iconclass']?.config?.update_iconclass?.restrict_time === true) {
        iconclass_config = info.config.plugin['custom-data-type-iconclass'].config.update_iconclass;
        // check if hours are configured
        if (iconclass_config?.from_time !== false && iconclass_config?.to_time !== false) {
            const now = new Date();
            const hour = now.getHours();
            // check if hours do not match
            if (!isInTimeRange(hour, iconclass_config.from_time, iconclass_config.to_time)) {
                // exit if hours do not match
                outputData({
                    "state": {
                        "theend": 2,
                        "log": ["hours do not match, cancel update"]
                    }
                });
            }
        }
    }

    access_token = info && info.plugin_user_access_token;

    if (access_token) {

        ////////////////////////////////////////////////////////////////////////////
        // get config and read the languages
        ////////////////////////////////////////////////////////////////////////////

        getConfigFromAPI().then(config => {
            databaseLanguages = config.system.config.languages.database;
            databaseLanguages = databaseLanguages.map((value, key, array) => {
                return value.value;
            });

            frontendLanguages = config.system.config.languages.frontend;

            const testDefaultLanguageConfig = config.plugin['custom-data-type-iconclass'].config.update_iconclass.default_language;
            if (testDefaultLanguageConfig) {
                if (testDefaultLanguageConfig.length == 2) {
                    defaultLanguage = testDefaultLanguageConfig;
                }
            }

            ////////////////////////////////////////////////////////////////////////////
            // availabilityCheck for iconclass-api
            ////////////////////////////////////////////////////////////////////////////
            let testURL = 'https://iconclass.org/1.json';
            https.get(testURL, res => {
                let testData = [];
                res.on('data', chunk => {
                    testData.push(chunk);
                });
                res.on('end', () => {
                    const testVocab = JSON.parse(Buffer.concat(testData).toString());
                    if (testVocab.n == "1") {
                        ////////////////////////////////////////////////////////////////////////////
                        // test successfull --> continue with custom-data-type-update
                        ////////////////////////////////////////////////////////////////////////////
                        process.stdin.on('readable', () => {
                            let chunk;
                            while ((chunk = process.stdin.read()) !== null) {
                                data = data + chunk
                            }
                        });
                        process.stdin.on('end', () => {
                            ///////////////////////////////////////
                            // continue with update-routine
                            ///////////////////////////////////////
                            try {
                                let payload = JSON.parse(data)
                                main(payload)
                            } catch (error) {
                                console.error("caught error", error)
                                outputErr(error)
                            }
                        });
                    } else {
                        console.error('Error while interpreting data from iconclass-API.');
                    }
                });
            }).on('error', err => {
                console.error('Error while receiving data from iconclass-API: ', err.message);
            });
        }).catch(error => {
            console.error('Es gab einen Fehler beim Laden der Konfiguration:', error);
        });
    } else {
        console.error("kein Accesstoken gefunden");
    }
})();
