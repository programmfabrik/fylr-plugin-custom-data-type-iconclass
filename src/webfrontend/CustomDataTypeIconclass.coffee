class CustomDataTypeIconclass extends CustomDataTypeWithCommonsAsPlugin

  #######################################################################
  # return name of plugin
  getCustomDataTypeName: ->
    "custom:base.custom-data-type-iconclass.iconclass"

  #######################################################################
  # overwrite getCustomMaskSettings
  getCustomMaskSettings: ->
    if @ColumnSchema
      return @FieldSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # overwrite getCustomSchemaSettings
  getCustomSchemaSettings: ->
    if @ColumnSchema
      return @ColumnSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # configure used facet
  getFacet: (opts) ->
    opts.field = @
    new CustomDataTypeIconclassFacet(opts)
    
  #######################################################################
  # overwrite getCustomSchemaSettings
  name: (opts = {}) ->
    if ! @ColumnSchema
      if opts?.callfrompoolmanager && opts?.name != ''
        return opts.name
      else
        return "noNameSet"
    else
      return @ColumnSchema?.name

  #######################################################################
  # return name (l10n) of plugin
  getCustomDataTypeNameLocalized: ->
    $$("custom.data.type.iconclass.name")

  #######################################################################
  # returns the databaseLanguages
  getDatabaseLanguages: () ->
    databaseLanguages = ez5.loca.getLanguageControl().getLanguages().slice()
    return databaseLanguages
    
    
  #######################################################################
  # returns markup to display in expert search
  #######################################################################
  renderSearchInput: (data) ->
      that = @
      if not data[@name()]
          data[@name()] = {}

      form = @renderEditorInput(data, '', {})

      CUI.Events.listen
            type: "data-changed"
            node: form
            call: =>
                CUI.Events.trigger
                    type: "search-input-change"
                    node: form
      form.DOM

  #######################################################################
  # make searchfilter for expert-search
  #######################################################################
  getSearchFilter: (data, key=@name()) ->
      that = @

      # search for empty values
      if data[key+":unset"]
          filter =
              type: "in"
              fields: [ @fullName()+".conceptName" ]
              in: [ null ]
          filter._unnest = true
          filter._unset_filter = true
          return filter

      else if data[key+":has_value"]
        return @getHasValueFilter(data, key)

      # popup with tree: find all records which have the given uri in their ancestors
      filter =
          type: "complex"
          search: [
              type: "match"
              bool: "must"
              mode: "fulltext"
              phrase: false
              fields: [ @path() + '.' + @name() + ".conceptAncestors" ]
          ]
      if ! data[@name()]
          filter.search[0].string = null
      else if data[@name()]?.conceptURI
          filter.search[0].string = data[@name()].conceptURI
      else
          filter = null

      filter


  #######################################################################
  # handle suggestions-menu
  #######################################################################
  __updateSuggestionsMenu: (cdata, cdata_form, input_searchstring, input, suggest_Menu, searchsuggest_xhr, layout, opts) ->
    that = @

    delayMillisseconds = 50

    # show loader
    menu_items = [
        text: $$('custom.data.type.iconclass.modal.form.loadingSuggestions')
        icon_left: new CUI.Icon(class: "fa-spinner fa-spin")
        disabled: true
    ]
    itemList =
      items: menu_items
    suggest_Menu.setItemList(itemList)

    setTimeout ( ->

        input_searchstring = input_searchstring.replace /^\s+|\s+$/g, ""
        input_searchstring = input_searchstring.replace '*', ''
        input_searchstring = input_searchstring.replace ' ', ''

        # check if searchstring starts with a notation (number)
        searchStringIsNotation = false
        if isNaN(input_searchstring[0]) == false
          searchStringIsNotation = true

        suggest_Menu.show()

        # limit-Parameter
        countSuggestions = 20

        # run autocomplete-search via xhr
        if searchsuggest_xhr.xhr != undefined
            # abort eventually running request
            searchsuggest_xhr.xhr.abort()

        activeFrontendLanguage = that.getFrontendLanguage()

        searchUrl = 'https://iconclass.org/api/search?q=' + encodeURIComponent(input_searchstring) + '&lang=' + activeFrontendLanguage + '&size=999&page=1&sort=rank&keys=0';
        ### 
        result is like
            {
                "result": [
                    "11H(JULIAN)131",
                    "11H(JULIAN)13",
                    "11H(JULIAN)119",
                    "11H(JULIAN)84",...
                ],
                "total": 148
            }
        ###

        if searchStringIsNotation
          searchUrl = 'https://iconclass.org/' + encodeURIComponent(input_searchstring) + '.json'

        ###
        result is like
            {
                "n": "11H(JULIAN)2",
                "p": [
                    "1",
                    "11",
                    "11H",
                    "11H(...)",
                    "11H(JULIAN)",
                    "11H(JULIAN)2"
                ],
                "b": "11H(JULIAN)2",
        ###

        # start request
        searchsuggest_xhr.xhr = new (CUI.XHR)(url: searchUrl)
        searchsuggest_xhr.xhr.start().done((data, status, statusText) ->
            extendedInfo_xhr = { "xhr" : undefined }
            if !searchStringIsNotation
              if data.result
                data = data.result
            else
              if data.length != 0
                data = [data]
            menu_items = []
            for suggestion, key in data
              do(key) ->
                if searchStringIsNotation
                  # get label in users frontendLanguage
                  if suggestion.txt[activeFrontendLanguage]
                    suggestionsLabel = suggestion.txt[activeFrontendLanguage]
                  else
                    suggestionsLabel = suggestion.txt.de
                  suggestionsLabel = suggestion.n + ' - ' + suggestionsLabel
                  suggestionsURI = 'https://iconclass.org/' + suggestion.n
                  item =
                    text: suggestionsLabel
                    value: suggestion
                    tooltip:
                      markdown: true
                      placement: "ne"
                      content: (tooltip) ->
                        # show infopopup
                        that.__getAdditionalTooltipInfo(suggestionsURI, tooltip, extendedInfo_xhr)
                        new CUI.Label(icon: "spinner", text: $$('custom.data.type.iconclass.modal.form.popup.loadingstring'))
                  menu_items.push item
                if !searchStringIsNotation
                  suggestionsURI = 'https://iconclass.org/' + suggestion
                  item =
                    text: suggestion
                    value: suggestion
                    tooltip:
                      markdown: true
                      placement: "ne"
                      content: (tooltip) ->
                        # show infopopup
                        that.__getAdditionalTooltipInfo(suggestionsURI, tooltip, extendedInfo_xhr)
                        new CUI.Label(icon: "spinner", text: $$('custom.data.type.iconclass.modal.form.popup.loadingstring'))
                  menu_items.push item
            # create new menu with suggestions
            itemList =
              # choose record from suggestions
              onClick: (ev2, btn) ->
                  iconclassInfo = btn.getOpt("value")
                  ###############################################
                  # if search string is a notation
                  ###############################################
                  if searchStringIsNotation
                    if iconclassInfo?.n
                      ###############################################
                      # brackets with dots provided?
                      ###############################################
                      if iconclassInfo.n.includes '(...)'
                        # open popup and force user to input bracketsvalue
                        # Example: 25G4(...)
                        chosenTempUri = 'https://iconclass.org/' + iconclassInfo.n
                        CUI.prompt(text: $$('custom.data.type.iconclass.modal.form.popup.brackets.select') + " " + chosenTempUri + "\n\n" + $$('custom.data.type.iconclass.modal.form.popup.brackets.choose'), "1")
                        .done (input) =>
                          inputUpperCase = input.toUpperCase()
                          inputLowerCase = input.toLowerCase()

                          # replace in notation
                          iconclassInfo.n = iconclassInfo.n.replace('(...)', "(" + inputUpperCase + ")")
                          # replace in labels
                          for iconclassLabelKey, iconclassLabelValue of iconclassInfo.txt
                            newLabel = iconclassLabelValue
                            newLabel = newLabel.replace(" (mit NAMEN)", ': ' + inputLowerCase)
                            newLabel = newLabel.replace(" (with NAME)", ': ' + inputLowerCase)
                            newLabel = newLabel.replace(" (avec NOM)", ': ' + inputLowerCase)
                            newLabel = newLabel.replace(" (col NOME)", ': ' + inputLowerCase)
                            newLabel = newLabel.replace(" (NIMEN kanssa)", ': ' + inputLowerCase)
                            iconclassInfo.txt[iconclassLabelKey] = newLabel

                          # lock conceptURI in savedata
                          cdata.conceptURI = 'https://iconclass.org/' + iconclassInfo.n
                          cdata.frontendLanguage = activeFrontendLanguage

                          # lock conceptName in savedata
                          cdata.conceptName = IconclassUtil.getConceptNameFromObject iconclassInfo, cdata

                          cdata.conceptAncestors = []
                          # if treeview, add ancestors
                          if iconclassInfo?.p?.length > 0
                            # save ancestor-uris to cdata
                            for ancestor in iconclassInfo.p
                              cdata.conceptAncestors.push 'https://iconclass.org/' + ancestor
                          # add own uri to ancestor-uris
                          cdata.conceptAncestors.push 'https://iconclass.org/' + iconclassInfo.n

                          cdata.conceptAncestors = cdata.conceptAncestors.join(' ')

                          # facetTerm
                          cdata.facetTerm = IconclassUtil.getFacetTerm(iconclassInfo, that.getDatabaseLanguages())
                          
                          # lock conceptFulltext in savedata
                          cdata._fulltext = IconclassUtil.getFullTextFromObject iconclassInfo, false
                          # lock standard in savedata
                          cdata._standard = IconclassUtil.getStandardTextFromObject that, iconclassInfo, cdata, false

                          # update the layout in form
                          that.__updateResult(cdata, layout, opts)
                          @
                        .fail =>
                          cdata = {}
                          that.__updateResult(cdata, layout, opts)
                          @
                      ###############################################
                      # if no bracketsvalue in chosen record
                      ###############################################
                      else
                        # lock conceptURI in savedata
                        if iconclassInfo?.n
                          cdata.conceptURI = 'https://iconclass.org/' + iconclassInfo.n
                        else
                          cdata.conceptURI = 'https://iconclass.org/' + iconclassInfo
                        
                        cdata.frontendLanguage = activeFrontendLanguage

                        fullInfoUrl = 'https://iconclass.org/' + iconclassInfo + '.json'

                        # lock conceptName in savedata
                        cdata.conceptName = IconclassUtil.getConceptNameFromObject iconclassInfo, cdata

                        cdata.conceptAncestors = []
                        # if treeview, add ancestors
                        if iconclassInfo?.p?.length > 0
                          # save ancestor-uris to cdata
                          for ancestor in iconclassInfo.p
                            cdata.conceptAncestors.push 'https://iconclass.org/' + ancestor
                        # add own uri to ancestor-uris
                        cdata.conceptAncestors.push 'https://iconclass.org/' + iconclassInfo.n

                        cdata.conceptAncestors = cdata.conceptAncestors.join(' ')

                        # facetTerm
                        cdata.facetTerm = IconclassUtil.getFacetTerm(iconclassInfo, that.getDatabaseLanguages())
                        
                        # lock conceptFulltext in savedata
                        cdata._fulltext = IconclassUtil.getFullTextFromObject iconclassInfo, false
                        # lock standard in savedata
                        cdata._standard = IconclassUtil.getStandardTextFromObject that, iconclassInfo, cdata, false

                        that.__updateResult(cdata, layout, opts)
                        @
                  ###############################################
                  # if search string is NOT a notation
                  ###############################################
                  else if !searchStringIsNotation
                    # get full data from iconclass

                    fullInfoUrl = 'https://iconclass.org/' + iconclassInfo + '.json'
                    # start request
                    searchsuggest_xhr.xhr = new (CUI.XHR)(url: fullInfoUrl)
                    searchsuggest_xhr.xhr.start().done((data, status, statusText) ->
                      # lock conceptURI in savedata
                      cdata.conceptURI = 'https://iconclass.org/' + iconclassInfo
                      cdata.frontendLanguage = activeFrontendLanguage

                      # lock conceptName in savedata
                      cdata.conceptName = IconclassUtil.getConceptNameFromObject data, cdata

                      cdata.conceptAncestors = []
                      # if treeview, add ancestors
                      if data?.p?.length > 0
                        # save ancestor-uris to cdata
                        for ancestor in data.p
                          cdata.conceptAncestors.push 'https://iconclass.org/' + ancestor
                      # add own uri to ancestor-uris
                      cdata.conceptAncestors.push 'https://iconclass.org/' + iconclassInfo

                      cdata.conceptAncestors = cdata.conceptAncestors.join(' ')

                      # facetTerm
                      cdata.facetTerm = IconclassUtil.getFacetTerm(data, that.getDatabaseLanguages())
                      
                      # lock conceptFulltext in savedata
                      cdata._fulltext = IconclassUtil.getFullTextFromObject data, false
                      # lock standard in savedata
                      cdata._standard = IconclassUtil.getStandardTextFromObject that, data, cdata, false

                      that.__updateResult(cdata, layout, opts)
                      @
                    )

              items: menu_items

            # if no suggestions: set "empty" message to menu
            if itemList.items.length == 0
              itemList =
                items: [
                  text: $$('custom.data.type.iconclass.modal.form.popup.suggest.nohit')
                  value: undefined
                ]
            suggest_Menu.setItemList(itemList)
            suggest_Menu.show()
        )
    ), delayMillisseconds


  #######################################################################
  # render editorinputform
  renderEditorInput: (data, top_level_data, opts) ->
    if not data[@name()]
        cdata = {
            conceptName : ''
            conceptURI : ''
        }
        data[@name()] = cdata
    else
        cdata = data[@name()]
    @__renderEditorInputPopover(data, cdata, opts)

  #######################################################################
  # get frontend-language
  getFrontendLanguage: () ->
    # language
    desiredLanguage = ez5.loca.getLanguage()
    desiredLanguage = desiredLanguage.split('-')
    desiredLanguage = desiredLanguage[0]

    desiredLanguage

  #######################################################################
  # show tooltip with loader and then additional info (for extended mode)
  __getAdditionalTooltipInfo: (iconclassURI, tooltip, extendedInfo_xhr, context = null) ->
    that = @
    if(iconclassURI.indexOf('%') != -1)
      iconclassURI = decodeURIComponent(iconclassURI)
    if context
      that = context
    # abort eventually running request
    if extendedInfo_xhr.xhr != undefined
      extendedInfo_xhr.xhr.abort()

    # start new request to DANTE-API
    url = iconclassURI + '.json'
    extendedInfo_xhr.xhr = new (CUI.XHR)(url: url)
    extendedInfo_xhr.xhr.start()
    .done((data, status, statusText) ->
      htmlContent = IconclassUtil.getPreview(data, that.getFrontendLanguage())
      if htmlContent
        tooltip.DOM.innerHTML = htmlContent
      else
        tooltip.DOM.innerHTML = '<div class="iconclassTooltip" style="padding: 10px">' + $$('custom.data.type.iconclass.modal.form.popup.no_information_found') + '</div>'
      tooltip.autoSize()
    )
    return

  #######################################################################
  # build treeview-Layout with treeview
  buildAndSetTreeviewLayout: (popover, layout, cdata, cdata_form, that, topMethod = 0, returnDfr = false, opts) ->
    that = @
    treeview = new Iconclass_ListViewTree(popover, layout, cdata, cdata_form, that, opts)
    activeFrontendLanguage = that.getFrontendLanguage()

    # maybe deferred is wanted?
    if returnDfr == false
      treeview.getTopTreeView(activeFrontendLanguage)
    else
      treeviewDfr = treeview.getTopTreeView(activeFrontendLanguage)

    treeviewPane = new CUI.Pane
        class: "cui-pane iconclass_treeviewPane"
        top:
            content: [
                new CUI.PaneHeader
                    left:
                        content:
                            new CUI.Label(text: $$('custom.data.type.iconclass.modal.form.popup.choose'))
            ]
        center:
            content: [
                treeview.treeview
              ,
                cdata_form
            ]

    @popover.setContent(treeviewPane)

    # maybe deferred is wanted?
    if returnDfr == false
      return treeview
    else
      return treeviewDfr

  #######################################################################
  # show popover and fill it with the form-elements
  showEditPopover: (btn, data, cdata, layout, opts) ->
    that = @

    # init popover
    @popover = new CUI.Popover
      element: btn
      placement: "wn"
      class: "commonPlugin_Popover"

    # do search-request for all the top-entrys of vocabulary
    @buildAndSetTreeviewLayout(@popover, layout, cdata, null, that, 1, false, opts)

    @popover.show()

  #######################################################################
  # create form (POPOVER)
  #######################################################################
  __getEditorFields: (cdata) ->
    that = @
    fields = []

    # searchfield (autocomplete)
    option =  {
          type: CUI.Input
          class: "commonPlugin_Input"
          undo_and_changed_support: false
          form:
              label: $$("custom.data.type.iconclass.modal.form.text.searchbar")
          placeholder: $$("custom.data.type.iconclass.modal.form.text.searchbar.placeholder")
          name: "searchbarInput"
        }
    fields.push option

    fields

  #######################################################################
  # checks the form and returns status
  getDataStatus: (cdata) ->
      if (cdata)
        if cdata.conceptURI and cdata.conceptName
          # check url for valididy
          uriCheck = false
          if cdata.conceptURI.trim() != ''
            uriCheck = true

          nameCheck = if cdata.conceptName then cdata.conceptName.trim() else undefined

          if uriCheck and nameCheck
            return "ok"

          if cdata.conceptURI.trim() == '' || cdata.conceptName.trim() == ''
            return "empty"

          return "invalid"
      return "empty"

  #######################################################################
  # renders the "resultmask" (outside popover)
  __renderButtonByData: (cdata) ->
    that = @
    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new CUI.EmptyLabel(text: $$("custom.data.type.iconclass.edit.no_entry")).DOM
      when "invalid"
        return new CUI.EmptyLabel(text: $$("custom.data.type.iconclass.edit.no_valid_entry")).DOM

    extendedInfo_xhr = { "xhr" : undefined }

    # active frontendlanguage
    frontendLanguage = ez5.loca.getLanguage()

    # default label is conceptName
    outputLabel = cdata.conceptName

    # logic: if the conceptLabel is not set by hand and it is available in the given frontendlanguage -->
    #         choose label from _standard.l10n
    if cdata?._standard?.l10ntext?[frontendLanguage] && cdata?.conceptNameChosenByHand != true
      outputLabel = cdata._standard.l10ntext[frontendLanguage]

    # output Button with Name of picked dante-Entry and URI
    cdata.conceptURI
    new CUI.HorizontalLayout
      maximize: true
      left:
        content:
          new CUI.Label
            centered: false
            text: outputLabel
      center:
        content:
          new CUI.ButtonHref
            name: "outputButtonHref"
            class: "pluginResultButton"
            appearance: "link"
            size: "normal"
            href: cdata.conceptURI
            target: "_blank"
            class: "cdt_iconclass_smallMarginTop"
            tooltip:
              markdown: true
              placement: 'nw'
              content: (tooltip) ->
                # get details-data
                that.__getAdditionalTooltipInfo(cdata.conceptURI, tooltip, extendedInfo_xhr)
                # loader, until details are xhred
                new CUI.Label(icon: "spinner", text: $$('custom.data.type.iconclass.modal.form.popup.loadingstring'))
      right: null
    .DOM

  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    if Object.keys(custom_settings).length == 0
      ['Ohne Optionen']

CustomDataType.register(CustomDataTypeIconclass)
