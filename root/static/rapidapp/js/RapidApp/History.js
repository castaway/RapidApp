/**
 * AutoHistory API:
 *
 * The module AutoHistory has the following public method:
 *   recordHistEvent(id, oldVal, newVal)
 *      id     - the component ID of a ExtJS component which supports the NavState interface,
 *      oldVal - a string representing the previous navigation state
 *      newVal - a string representing the new navigation state.
 *
 * The strings can be anything the caller wants.  They will be passed back as-is.
 *
 * The caller must support the following interface:
 *
 *   getNavState(): navVal
 *      navVal - a string representing the current navigation state
 *   setNavState(navVal)
 *      navVal - a string previously passed to recordHistEvent
 */

Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.HistoryInit_new = function() {
	Ext.History.init();

	Ext.History.on('change', function(token) {
		
		// nav schmea: starts with '!/'
		if(token.search('!/') == 0) {
			var url = token.substring(1); // strip leading !
			var params = {};
				
			var parts = url.split('?');
			if(parts[1]) {
				url = parts[0];
				params = Ext.urlDecode(parts[1]);
			}
			
			var loadTarget = Ext.getCmp('main-load-target');
			
			loadTarget.loadContent({ autoLoad: { 
				url: url, 
				params: params 
			}});
		}
		
	});
}




Ext.ux.RapidApp.HistoryInit = function() {
	Ext.History.init();
	Ext.History.on('change', function(token) { Ext.ux.RapidApp.AutoHistory.handleHistChange(token); });
	Ext.ux.RapidApp.AutoHistory.installSafeguard();
};


Ext.ux.RapidApp.AutoHistory= {
	navIdx: 0,
	wrapIdx: function(idx) { return idx > 99? (idx - 100) : (idx < 0? idx + 100 : idx); },
	isForwardNav: function(oldIdx, newIdx) { var diff= this.wrapIdx(newIdx-oldIdx); return diff < 50; },
	currentNav: '',
	
	// add a fake nav event to prevent the user from backing out of the page
	installSafeguard: function() {
		this.currentNav= ''+this.navIdx+':::';
		Ext.History.add(this.currentNav);
	},
	
	// follow a nav event given to us by the application
	recordHistEvent: function(id, oldval, newval) {
		if (!newval) return;
		
		this.navIdx= this.wrapIdx(this.navIdx+1);
		this.currentNav= ''+this.navIdx+':'+id+':'+oldval+':'+newval;
		//console.log('recordHistEvent '+this.currentNav);
		
		Ext.History.add(this.currentNav);
	},
	
	performNav: function(id, newVal) {
		if (!id) return;
		if (!newVal) return;
		var target= Ext.getCmp(id);
		if (!target) return;
		//console.log('AutoHistory.performNav: '+id+'->setNav '+newVal);
		target.setNavState(newVal);
	},
	
	// respond to user back/forward navigation, but ignore ones generated by recordHistEvent
	handleHistChange: function(navTarget) {
		if (!navTarget) {
			if (this.currentNav) {
				var parts= this.currentNav.split(':');
				this.performNav(parts[1], parts[2]);
			}
			this.installSafeguard();
			return;
		}
		
		// ignore events caused by recordHistEvent
		if (navTarget != this.currentNav) {
			//console.log('AutoHistory.handleHistChange: '+this.currentNav+' => '+navTarget);
			var parts= navTarget.split(':');
			var navTargetIdx= parseInt(parts[0]);
			if (this.isForwardNav(this.navIdx, navTargetIdx)) {
				this.performNav(parts[1], parts[3]);
			}
			else {
				var parts= this.currentNav.split(':');
				this.performNav(parts[1], parts[2]);
			}
			this.currentNav= navTarget;
			this.navIdx= navTargetIdx;
		}
	}
};




Ext.override(Ext.TabPanel, {
	initComponent_orig: Ext.TabPanel.prototype.initComponent,
	initComponent: function() {
		//this.constructor.prototype.initComponent.call(this);
		this.initComponent_orig.apply(this,arguments);
		this.internalTabChange= 0;
		
		this.on('beforetabchange', function(tabPanel, newTab, currentTab) {
			if (newTab && currentTab && !this.internalTabChange) {
				Ext.ux.RapidApp.AutoHistory.recordHistEvent(tabPanel.id, currentTab.id, newTab.id);
			}
			this.internalTabChange= 0;
			return true;
		});
	},
	setNavState: function(navVal) {
		var newTab= Ext.getCmp(navVal);
		if (newTab) {
			this.internalTabChange= 1;
			this.setActiveTab(newTab);
		}
	},
	getNavState: function() { return this.getActiveTab()? this.getActiveTab().id : ""; }
});

