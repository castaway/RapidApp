Ext.ux.RapidApp.Plugin.TemplateControllerPanel = Ext.extend(Ext.util.Observable,{
	
	init: function(panel) {
    this.panel = panel;
		panel.on('afterrender',this.onAfterRender,this);
	},
 
	onAfterRender: function() {
    this.panel.getEl().on('click',function(event,node) {
      var target = event.getTarget(null,null,true);
      var El = new Ext.Element(target);
      if (El.hasClass('edit')) {
        var tplEl = El.parent('div.ra-template');
        if (tplEl) { return this.editTplEl(tplEl); }
      }
      else if (El.hasClass('create')) {
        var tplEl = El.parent('div.ra-template');
        if (tplEl) { return this.createTplEl(tplEl); }
      }
    },this);
	},
  
  getTplElMeta: function(tplEl) {
    var metaEl = tplEl.child('div.meta');
    var name = metaEl.child('div.template-name').dom.innerHTML;
    name = name.replace(/(\r\n|\n|\r)/gm,""); // <-- strip newlines
    return {
      name: name
    };
  },
  
  editTplEl: function(tplEl) {
    var meta = this.getTplElMeta(tplEl);
    return this.editTemplate(meta);
  },
  
  editTemplate: function(meta) {
    var url = [
      this.panel.template_controller_url,
      'get', meta.name
    ].join('/');
    
    var success_fn = function(response,options) {
      this.loadEditor(meta.name,response.responseText);
    };
    
    Ext.Ajax.request({
      url: url,
      method: 'GET',
      success: success_fn,
      //failure: failure_fn
      scope: this
    });
  },
  
  createTplEl: function(tplEl) {
    var meta = this.getTplElMeta(tplEl);
    return this.createTemplate(meta);
  },
  
  createTemplate: function(meta) {
    var url = [
      this.panel.template_controller_url,
      'create', meta.name
    ].join('/');
    
    var success_fn = function(response,options) {
      this.tabReload();
      this.editTemplate(meta);
    };
    
    Ext.Ajax.request({
      url: url,
      method: 'GET',
      success: success_fn,
      //failure: failure_fn
      scope: this
    });
  },
  
  tabReload: function() {
    var tab = this.tab || this.panel.ownerCt;
    var tp = tab.ownerCt;
    if(Ext.isFunction(tp.loadContent) && Ext.isObject(tab.loadContentCnf)) {
      var cnf = tab.loadContentCnf;
      tp.remove(tab);
      this.tab = tp.loadContent(cnf);
    }
  },
  
  setTemplate: function(name,content,skip_validate) {
  
    var set_url = [
      this.panel.template_controller_url,
      'set', name
    ].join('/');
    
    var params = { content: content };
    if(skip_validate) {
      params.skip_validate = 1;
    }
    
    Ext.Ajax.request({
      url: set_url,
      method: 'POST',
      params: params,
      success: function(response,options) {
        this.win.close();
        
        // Reload the tab
        this.tabReload();
        
        // TODO: reload the template element if nested template
        
      },
      failure: function(response,options) {
        if(response.status == 418) {
          Ext.Msg.show({
            title: 'Errors in template',
            msg: [
              '<br><b>Template contains errors:</b><br><br>',
              '<div class="ra-template">',
                '<div class="tpl-error">',
                  '<div class="error-msg">',
                    Ext.util.Format.nl2br(response.responseText),
                  '</div>',
                '</div>',
              '</div>',
              '<br>',
              '<b>Save anyway?</b><br>'
            ].join(''),
            buttons: Ext.Msg.YESNO,
            icon: Ext.Msg.WARNING,
            minWidth: 275,
            fn: function(button_id) {
              if(button_id == 'yes') {
                // Call again, this time with skip_validate:
                this.setTemplate(name,content,true);
              }
            },
            scope: this
          });
        }
        else {
          Ext.Msg.show({
            title: 'Error',
            msg: Ext.util.Format.nl2br(response.responseText),
            buttons: Ext.Msg.OK,
            icon: Ext.Msg.ERROR,
            minWidth: 275
          });
        }
      },
      scope: this
    });
  },
  
  loadEditor: function(name,content) {
  
    var fp, panel = this.panel;
		
		var saveFn = function(btn) {
			var form = fp.getForm();
			var data = form.findField('content').getRawValue();
      return this.setTemplate(name,data);
		};
		
		fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 160,
			labelPad: 15,
			//bodyStyle: 'padding: 10px 10px 5px 5px;',
      bodyStyle: 'padding: 0px 0px 5px 0px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			items: [
				{
					name: 'content',
					itemId: 'content',
          xtype: 'ra-htmleditor',
          no_autosizers: true,
					//xtype: 'textarea',
					//style: 'font-family: monospace;',
					fieldLabel: 'Template',
					hideLabel: true,
					value: content,
					anchor: '-0 -0',
				}
			],
			
			buttons: [
				{
					name: 'save',
					text: 'Save',
					iconCls: 'icon-save-ok',
					width: 100,
					formBind: true,
					scope: this,
					handler: saveFn
				},
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
  
    if(this.win) { 
      this.win.close(); 
    }
    
    this.win = new Ext.Window({
			title: ["Edit Template ('",name,"')"].join(''),
			layout: 'fit',
			width: 800,
			height: 600,
			minWidth: 400,
			minHeight: 250,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
    
    this.win.show();
  }
	
});
Ext.preg('template-controller-panel',Ext.ux.RapidApp.Plugin.TemplateControllerPanel);

