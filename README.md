> This Plugin / Repo is being maintained by a community of developers.
There is no warranty given or bug fixing guarantee; especially not by
Programmfabrik GmbH. Please use the github issue tracking to report bugs
and self organize bug fixing. Feel free to directly contact the committing
developers.

# fylr-custom-data-type-iconclass

This is a plugin for [fylr](https://docs.fylr.io/) with Custom Data Type `CustomDataTypeIconclass` for references to entities of the [Iconclass-Vokabulary (http://iconclass.org/)](http://iconclass.org/).

The Plugins uses the mechanisms from <http://iconclass.org/help/lod> for the communication with Iconclass.

Note: For technical reasons, the API requests run via a proxy at the central office of the joint library network ("Verbundzentrale des Gemeinsamen Bibliotheksverbundes").

## installation

The latest version of this plugin can be found [here](https://github.com/programmfabrik/fylr-plugin-custom-data-type-iconclass/releases/latest/download/customDataTypeIconclass.zip).

The ZIP can be downloaded and installed using the plugin manager, or used directly (recommended).

Github has an overview page to get a list of [all releases](https://github.com/programmfabrik/fylr-plugin-custom-data-type-iconclass/releases/).



## configuration

As defined in `manifest.master.yml` this datatype can be configured:

### Schema options

### Mask options
* editordisplay: default or condensed (oneline)

## saved data
* conceptName
    * Preferred label of the linked record
* conceptURI
    * URI to linked record
* conceptFulltext
    * fulltext-string which contains: PrefLabels, AltLabels, HiddenLabels, Notations
* conceptAncestors
    * URI's of all given ancestors
* _fulltext
    * easydb-fulltext
* _standard
    * easydb-standard
* facetTerm
    * custom facets, which support multilingual facetting

## updater

Note: The automatic nightly updater can be configured. Make sure to also activate the corresponding fylr service.


## sources

The source code of this plugin is managed in a git repository at <https://github.com/programmfabrik/easydb-custom-data-type-iconclass>. Please use [the issue tracker](https://github.com/programmfabrik/easydb-custom-data-type-iconclass/issues) for bug reports and feature requests!
