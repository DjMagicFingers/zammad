class App.TicketOverview extends App.Controller
  className: 'overviews'

  constructor: ->
    super
    @render()

  render: ->
    @html App.view('ticket_overview')()

    @navBarControllerVertical = new Navbar
      el:       @$('.overview-header')
      view:     @view
      vertical: true

    @navBarController = new Navbar
      el:   @$('.sidebar')
      view: @view

    @contentController = new Table
      el:   @$('.overview-table')
      view: @view

  active: (state) =>
    @activeState = state

  isActive: =>
    @activeState

  url: =>
    "#ticket/view/#{@view}"

  show: (params) =>

    # highlight navbar
    @navupdate '#ticket/view'

    # redirect to last overview if we got called in first level
    @view = params['view']
    if !@view && @viewLast
      @navigate "ticket/view/#{@viewLast}", true
      return

    # build nav bar
    if @navBarController
      @navBarController.update
        view:        @view
        activeState: true

    if @navBarControllerVertical
      @navBarControllerVertical.update
        view:        @view
        activeState: true

    # do not rerender overview if current overview is requested again
    return if @viewLast is @view

    # remember last view
    @viewLast = @view

    # build content
    if @contentController
      @contentController.update(
        view: @view
      )

  hide: =>
    if @navBarController
      @navBarController.active(false)
    if @navBarControllerVertical
      @navBarControllerVertical.active(false)

  changed: ->
    false

  release: ->
    # no

class Navbar extends App.Controller
  elements:
    '.js-tabsHolder': 'tabsHolder'
    '.js-tabsClone': 'clone'
    '.js-tabClone': 'tabClone'
    '.js-tabs': 'tabs'
    '.js-tab': 'tab'
    '.js-dropdown': 'dropdown'
    '.js-toggle': 'dropdownToggle'
    '.js-dropdownItem': 'dropdownItem'

  events:
    'click .js-tab': 'activate'
    'click .js-dropdownItem': 'navigateTo'
    'hide.bs.dropdown': 'onDropdownHide'
    'show.bs.dropdown': 'onDropdownShow'

  constructor: ->
    super

    @bindId = App.OverviewIndexCollection.bind(@render)

    # rerender view, e. g. on language change
    @bind 'ui:rerender', =>
      @render(App.OverviewIndexCollection.get())

    if @vertical
      $(window).on 'resize.navbar', @autoFoldTabs

  navigateTo: (event) ->
    location.hash = $(event.currentTarget).attr('data-target')

  onDropdownShow: =>
    @dropdownToggle.addClass('active')

  onDropdownHide: =>
    @dropdownToggle.removeClass('active')

  activate: (event) =>
    @tab.removeClass('active')
    $(event.currentTarget).addClass('active')

  release: =>
    if @vertical
      $(window).off 'resize.navbar', @autoFoldTabs
    if @bindId
      App.OverviewIndexCollection.unbind(@bindId)

  autoFoldTabs: =>
    items = App.OverviewIndexCollection.get()
    @html App.view("agent_ticket_view/navbar#{ if @vertical then '_vertical' }")
      items: items
      isAgent: @isRole('Agent')

    while @clone.width() > @tabsHolder.width()
      @tabClone.not('.hide').last().addClass('hide')
      @tab.not('.hide').last().addClass('hide')
      @dropdownItem.filter('.hide').last().removeClass('hide')

    # if all tabs are visible
    # remove dropdown and dropdown button
    if @dropdownItem.not('.hide').size() is 0
      @dropdown.remove()
      @dropdownToggle.remove()

  active: (state) =>
    @activeState = state

  update: (params = {}) ->
    for key, value of params
      @[key] = value
    @render(App.OverviewIndexCollection.get())

  render: (data) =>
    return if !data

    # do not show vertical navigation if only one tab exists
    if @vertical
      if data && data.length <= 1
        @el.addClass('hidden')
      else
        @el.removeClass('hidden')

    # set page title
    if @activeState && @view && !@vertical
      for item in data
        if item.link is @view
          @title item.name, true

    # redirect to first view
    if @activeState && !@view && !@vertical
      view = data[0].link
      @navigate "ticket/view/#{view}", true
      return

    # add new views
    for item in data
      item.target = "#ticket/view/#{item.link}"
      if item.link is @view
        item.active = true
        activeOverview = item
      else
        item.active = false

    @html App.view("agent_ticket_view/navbar#{ if @vertical then '_vertical' else '' }")
      items: data

    if @vertical
      @autoFoldTabs()

class Table extends App.Controller
  events:
    'click [data-type=settings]': 'settings'
    'click [data-type=viewmode]': 'viewmode'

  constructor: ->
    super

    if @view
      @bindId = App.OverviewCollection.bind(@view, @render)

    # rerender view, e. g. on langauge change
    @bind 'ui:rerender', =>
      return if !@authenticate(true)
      @render(App.OverviewCollection.get(@view))

  release: =>
    if @bindId
      App.OverviewCollection.unbind(@bindId)

  update: (params) =>
    for key, value of params
      @[key] = value

    @view_mode = App.LocalStorage.get("mode:#{@view}", @Session.get('id')) || 's'
    @log 'notice', 'view:', @view, @view_mode

    return if !@view

    if @view
      if @bindId
        App.OverviewCollection.unbind(@bindId)
      @bindId = App.OverviewCollection.bind(@view, @render)

  render: (data) =>
    return if !data

    # use cache
    overview      = data.overview
    tickets_count = data.tickets_count
    ticket_ids    = data.ticket_ids

    # use cache if no local change
    App.Overview.refresh(overview, { clear: true })

    # get ticket list
    ticket_list_show = []
    for ticket_id in ticket_ids
      ticket_list_show.push App.Ticket.fullLocal(ticket_id)

    # if customer and no ticket exists, show the following message only
    if !ticket_list_show[0] && @isRole('Customer')
      @html App.view('customer_not_ticket_exists')()
      return

    @selected = @getSelected()

    # set page title
    @overview = App.Overview.find(overview.id)

    # render init page
    checkbox = true
    edit     = true
    if @isRole('Customer')
      checkbox = false
      edit     = false
    view_modes = [
      {
        name:  'S'
        type:  's'
        class: 'active' if @view_mode is 's'
      },
      {
        name:  'M'
        type:  'm'
        class: 'active' if @view_mode is 'm'
      }
    ]
    if @isRole('Customer')
      view_modes = []
    html = App.view('agent_ticket_view/content')(
      overview:   @overview
      view_modes: view_modes
      checkbox:   checkbox
      edit:       edit
    )
    html = $(html)

    @html html

    # create table/overview
    table = ''
    if @view_mode is 'm'
      table = App.view('agent_ticket_view/detail')(
        overview: @overview
        objects:  ticket_list_show
        checkbox: checkbox
      )
      table = $(table)
      table.delegate('[name="bulk_all"]', 'click', (e) ->
        if $(e.target).attr('checked')
          $(e.target).closest('table').find('[name="bulk"]').attr('checked', true)
        else
          $(e.target).closest('table').find('[name="bulk"]').attr('checked', false)
      )
      @$('.table-overview').append(table)
    else
      openTicket = (id,e) =>

        # open ticket via task manager to provide task with overview info
        ticket = App.Ticket.fullLocal(id)
        App.TaskManager.execute(
          key:        'Ticket-' + ticket.id
          controller: 'TicketZoom'
          params:
            ticket_id:   ticket.id
            overview_id: @overview.id
          show:       true
        )
        @navigate ticket.uiUrl()
      callbackTicketTitleAdd = (value, object, attribute, attributes, refObject) ->
        attribute.title = object.title
        value
      callbackLinkToTicket = (value, object, attribute, attributes, refObject) ->
        attribute.link = object.uiUrl()
        value
      callbackUserPopover = (value, object, attribute, attributes, refObject) ->
        attribute.class = 'user-popover'
        attribute.data =
          id: refObject.id
        value
      callbackOrganizationPopover = (value, object, attribute, attributes, refObject) ->
        attribute.class = 'organization-popover'
        attribute.data =
          id: refObject.id
        value
      callbackCheckbox = (id, checked, e) =>
        if @$('table').find('input[name="bulk"]:checked').length == 0
          @bulkForm.hide()
        else
          @bulkForm.show()
      callbackIconHeader = (headers) ->
        attribute =
          name:        'icon'
          display:     ''
          translation: false
          width:       '28px'
          displayWidth:28
          unresizable: true
        headers.unshift(0)
        headers[0] = attribute
        headers
      callbackIcon = (value, object, attribute, header, refObject) ->
        value = ' '
        attribute.class  = object.iconClass()
        attribute.link   = ''
        attribute.title  = object.iconTitle()
        value

      new App.ControllerTable(
        table_id:       "ticket_overview_#{@overview.id}"
        overview:       @overview.view.s
        el:             @$('.table-overview')
        model:          App.Ticket
        objects:        ticket_list_show
        checkbox:       checkbox
        groupBy:        @overview.group_by
        orderBy:        @overview.order.by
        orderDirection: @overview.order.direction
        class: 'table--light'
        bindRow:
          events:
            'click':  openTicket
        #bindCol:
        #  customer_id:
        #    events:
        #      'mouseover': popOver
        callbackHeader: [ callbackIconHeader ]
        callbackAttributes:
          icon:
            [ callbackIcon ]
          customer_id:
            [ callbackUserPopover ]
          organization_id:
            [ callbackOrganizationPopover ]
          owner_id:
            [ callbackUserPopover ]
          title:
            [ callbackLinkToTicket, callbackTicketTitleAdd ]
          number:
            [ callbackLinkToTicket, callbackTicketTitleAdd ]
        bindCheckbox:
          events:
            'click':  callbackCheckbox
      )

    @setSelected( @selected )

    # start user popups
    @userPopups()

    # start organization popups
    @organizationPopups()

    @bulkForm = new BulkForm
      holder: @el
      view: @view

    # start bulk action observ
    @el.append( @bulkForm.el )
    if @$('.table-overview').find('input[name="bulk"]:checked').length isnt 0
      @bulkForm.show()

    # show/hide bulk action
    @$('.table-overview').delegate('input[name="bulk"], input[name="bulk_all"]', 'click', (e) =>
      if @$('.table-overview').find('input[name="bulk"]:checked').length == 0
        @bulkForm.hide()
        @bulkForm.reset()
      else
        @bulkForm.show()
    )

    # deselect bulk_all if one item is uncheck observ
    @$('.table-overview').delegate('[name="bulk"]', 'click', (e) ->
      if !$(e.target).attr('checked')
        $(e.target).parents().find('[name="bulk_all"]').attr('checked', false)
    )

  getSelected: ->
    @ticketIDs = []
    @$('.table-overview').find('[name="bulk"]:checked').each( (index, element) =>
      ticket_id = $(element).val()
      @ticketIDs.push ticket_id
    )
    @ticketIDs

  setSelected: (ticketIDs) ->
    @$('.table-overview').find('[name="bulk"]').each( (index, element) ->
      ticket_id = $(element).val()
      for ticket_id_selected in ticketIDs
        if ticket_id_selected is ticket_id
          $(element).attr( 'checked', true )
    )

  viewmode: (e) =>
    e.preventDefault()
    @view_mode = $(e.target).data('mode')
    App.LocalStorage.set("mode:#{@view}", @view_mode, @Session.get('id'))
    @fetch()
    #@render()

  settings: (e) =>
    e.preventDefault()
    new App.OverviewSettings(
      overview_id: @overview.id
      view_mode:   @view_mode
      container:   @el.closest('.content')
    )

class BulkForm extends App.Controller
  className: 'bulkAction hide'

  events:
    'submit form':       'submit'
    'click .js-submit':  'submit'
    'click .js-confirm': 'confirm'
    'click .js-cancel':  'reset'

  constructor: ->
    super

    @configure_attributes_ticket = [
      { name: 'state_id',    display: 'State',    tag: 'select', multiple: false, null: true, relation: 'TicketState', translate: true, nulloption: true, default: '' },
      { name: 'priority_id', display: 'Priority', tag: 'select', multiple: false, null: true, relation: 'TicketPriority', translate: true, nulloption: true, default: '' },
      { name: 'group_id',    display: 'Group',    tag: 'select', multiple: false, null: true, relation: 'Group', nulloption: true  },
      { name: 'owner_id',    display: 'Owner',    tag: 'select', multiple: false, null: true, relation: 'User', nulloption: true }
    ]

    @holder = @options.holder
    @visible = false

    load = (data) =>
      App.Collection.loadAssets(data.assets)
      @formMeta = data.form_meta
      @render()
    @bindId = App.TicketCreateCollection.bind(load)

  release: =>
    App.TicketCreateCollection.unbind(@bindId)

  render: ->
    @el.css 'right', App.Utils.getScrollBarWidth()

    @html App.view('agent_ticket_view/bulk')()

    new App.ControllerForm(
      el: @$('#form-ticket-bulk')
      model:
        configure_attributes: @configure_attributes_ticket
        className:            'create'
        labelClass:           'input-group-addon'
      handlers: [
        @ticketFormChanges
      ]
      params:     {}
      filter:     @formMeta.filter
      noFieldset: true
    )

    new App.ControllerForm(
      el: @$('#form-ticket-bulk-comment')
      model:
        configure_attributes: [{ name: 'body', display: 'Comment', tag: 'textarea', rows: 4, null: true, upload: false, item_class: 'flex' }]
        className:            'create'
        labelClass:           'input-group-addon'
      noFieldset: true
    )

    @confirm_attributes = [
      { name: 'type_id',  display: 'Type',       tag: 'select', multiple: false, null: true, relation: 'TicketArticleType', filter: @articleTypeFilter, default: '9', translate: true, class: 'medium' }
      { name: 'internal', display: 'Visibility', tag: 'select', null: true, options: { true: 'internal', false: 'public' }, class: 'medium', item_class: '', default: false }
    ]

    new App.ControllerForm(
      el: @$('#form-ticket-bulk-typeVisibility')
      model:
        configure_attributes: @confirm_attributes
        className:            'create'
        labelClass:           'input-group-addon'
      noFieldset: true
    )

  articleTypeFilter: (items) ->
    for item in items
      if item.name is 'note'
        return [item]
    items

  confirm: =>
    @$('.js-action-step').addClass('hide')
    @$('.js-confirm-step').removeClass('hide')

    @makeSpaceForTableRows()

    # need a delay because of the click event
    setTimeout ( => @$('.textarea.form-group textarea').focus() ), 0

  reset: =>
    @$('.js-action-step').removeClass('hide')
    @$('.js-confirm-step').addClass('hide')

    if @visible
      @makeSpaceForTableRows()

  show: =>
    @el.removeClass('hide')
    @visible = true
    @makeSpaceForTableRows()

  hide: =>
    @el.addClass('hide')
    @visible = false
    @removeSpaceForTableRows()

  makeSpaceForTableRows: =>
    height = @el.height()
    scrollParent = @holder.scrollParent()
    isScrolledToBottom = scrollParent.prop('scrollHeight') is scrollParent.scrollTop() + scrollParent.outerHeight()

    @holder.css 'margin-bottom', height

    if isScrolledToBottom
      scrollParent.scrollTop scrollParent.prop('scrollHeight') - scrollParent.outerHeight()

  removeSpaceForTableRows: =>
    @holder.css 'margin-bottom', 0

  submit: (e) =>
    e.preventDefault()

    @bulk_count = @holder.find('.table-overview').find('[name="bulk"]:checked').length
    @bulk_count_index = 0
    @holder.find('.table-overview').find('[name="bulk"]:checked').each( (index, element) =>
      @log 'notice', '@bulk_count_index', @bulk_count, @bulk_count_index
      ticket_id = $(element).val()
      ticket = App.Ticket.find(ticket_id)
      params = @formParam(e.target)

      # update ticket
      ticket_update = {}
      for item of params
        if params[item] != ''
          ticket_update[item] = params[item]

      # validate article
      if params['body']
        article = new App.TicketArticle
        params.from      = @Session.get().displayName()
        params.ticket_id = ticket.id
        params.form_id   = @form_id

        sender           = App.TicketArticleSender.findByAttribute( 'name', 'Agent' )
        type             = App.TicketArticleType.find( params['type_id'] )
        params.sender_id = sender.id

        if !params['internal']
          params['internal'] = false

        @log 'notice', 'update article', params, sender
        article.load(params)
        errors = article.validate()
        if errors
          @log 'error', 'update article', errors
          @formEnable(e)
          return

      ticket.load(ticket_update)
      ticket.save(
        done: (r) =>
          @bulk_count_index++

          # reset form after save
          if article
            article.save(
              fail: (r) =>
                @log 'error', 'update article', r
            )

          # refresh view after all tickets are proceeded
          if @bulk_count_index == @bulk_count
            @hide()

            # fetch overview data again
            App.OverviewIndexCollection.fetch()
            App.OverviewCollection.fetch(@view)
      )
    )
    @holder.find('.table-overview').find('[name="bulk"]:checked').prop('checked', false)
    App.Event.trigger 'notify', {
      type: 'success'
      msg: App.i18n.translateContent('Bulk-Action executed!')
    }

class App.OverviewSettings extends App.ControllerModalNice
  buttonClose: true
  buttonCancel: true
  buttonSubmit: true
  headPrefix: 'Edit'

  content: =>
    @overview = App.Overview.find(@overview_id)
    @head     = @overview.name

    @configure_attributes_article = []
    if @view_mode is 'd'
      @configure_attributes_article.push({
        name:     'view::per_page'
        display:  'Items per page'
        tag:      'select'
        multiple: false
        null:     false
        default: @overview.view.per_page
        options: {
          5: ' 5'
          10: '10'
          15: '15'
          20: '20'
          25: '25'
        },
      })
    attributeOptions = {}
    attributeOptionsArray = []
    configure_attributes = App.Ticket.configure_attributes
    for row, attribute of App.Ticket.attributesGet()
      configure_attributes.push attribute
    for row in configure_attributes

      # ignore passwords
      if row.type isnt 'password'
        name = row.name

        # get correct data name
        if row.name.substr(row.name.length-4,4) is '_ids'
          name = row.name.substr(0, row.name.length-4)
        else if row.name.substr(row.name.length-3,3) is '_id'
          name = row.name.substr(0, row.name.length-3)

        if !attributeOptions[ name ]
          attributeOptions[ name ] = row.display
          attributeOptionsArray.push(
            {
              value:  name
              name:   row.display
            }
          )
    @configure_attributes_article.push({
      name:    "view::#{@view_mode}"
      display: 'Attributes'
      tag:     'checkbox'
      default: @overview.view[@view_mode]
      null:    false
      translate: true
      sortBy: null
      options: attributeOptionsArray
    },
    {
      name:    'order::by'
      display: 'Order'
      tag:     'select'
      default: @overview.order.by
      null:    false
      translate: true
      sortBy: null
      options: attributeOptionsArray
    },
    {
      name:    'order::direction'
      display: 'Direction'
      tag:     'select'
      default: @overview.order.direction
      null:    false
      translate: true
      options:
        ASC:   'up'
        DESC:  'down'
    },
    {
      name:    'group_by'
      display: 'Group by'
      tag:     'select'
      default: @overview.group_by
      null:    true
      nulloption: true
      translate:  true
      options:
        customer:       'Customer'
        organization:   'Organization'
        state:          'State'
        priority:       'Priority'
        group:          'Group'
        owner:          'Owner'
    })

    controller = new App.ControllerForm(
      model:     { configure_attributes: @configure_attributes_article }
      autofocus: false
    )
    controller.form

  onSubmit: (e) =>
    params = @formParam(e.target)

    # check if re-fetch is needed
    @reload_needed = false
    if @overview.order.by isnt params.order.by
      @overview.order.by = params.order.by
      @reload_needed = true

    if @overview.order.direction isnt params.order.direction
      @overview.order.direction = params.order.direction
      @reload_needed = true

    for key, value of params.view
      @overview.view[key] = value

    @overview.group_by = params.group_by

    @overview.save(
      done: =>

        # fetch overview data again
        if @reload_needed
          App.OverviewIndexCollection.fetch()
          App.OverviewCollection.fetch(@overview.link)
        else
          App.OverviewIndexCollection.trigger()
          App.OverviewCollection.trigger(@overview.link)

        # close modal
        @close()
    )

class TicketOverviewRouter extends App.ControllerPermanent
  constructor: (params) ->
    super

    # check authentication
    return if !@authenticate()

    # cleanup params
    clean_params =
      view: params.view

    App.TaskManager.execute(
      key:        'TicketOverview'
      controller: 'TicketOverview'
      params:     clean_params
      show:       true
      persistent: true
    )

App.Config.set( 'ticket/view', TicketOverviewRouter, 'Routes' )
App.Config.set( 'ticket/view/:view', TicketOverviewRouter, 'Routes' )
App.Config.set( 'TicketOverview', { controller: 'TicketOverview', authentication: true }, 'permanentTask' )
App.Config.set( 'TicketOverview', { prio: 1000, parent: '', name: 'Overviews', target: '#ticket/view', role: ['Agent', 'Customer'], class: 'overviews' }, 'NavBar' )
