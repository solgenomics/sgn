var SGN;
if( ! SGN ) SGN = {};
if( ! SGN.Search ) SGN.Search = {};

SGN.Search.Feature = {

    set_up_feature_search: function( args ) {
        var maximum_export_size = args.maximum_export_size || 10000;

        Ext.Loader.setConfig({enabled: true});

        Ext.require([
            'Ext.grid.*',
            'Ext.data.*',
            'Ext.util.*',
            'Ext.grid.PagingScroller'
        ]);

        // make the feature grid
        Ext.onReady(function(){

            var page_size = 100;

            Ext.define('Feature', {
                extend: 'Ext.data.Model',
                fields: [
                    'feature_id',
                    'organism',
                    'name',
                    'type',
                    'seqlen',
                    'locations',
                    'description'
                ],
                idProperty: 'feature_id'
            });

            function get_search_query( store ) {
                // get the filtering data from the store
                var post_vars = Ext.clone( store.proxy.extraParams );

                // filter out any form fields that are empty or just whitespace
                for( var name in post_vars ) {
                    var value = post_vars[name];
                    if( value == null || typeof value == 'string' && ! value.match(/[^\s]/) ) {
                        delete post_vars[name];
                    }
                }

                // get the sort settings from the store
                var sorter = store.sorters.first();
                post_vars.sort = sorter.property;
                post_vars.dir = sorter.direction;

                return post_vars;
            }

            // create the Data Store
            var feature_store = Ext.create('Ext.data.Store', {
                id:           'feature_store',
                pageSize:     page_size,
                model:        'Feature',
                remoteSort:   true,
                autoLoad:     true,

                listeners: {
                        // enable or disable the export and save
                        // toolbar based on how many features matched
                        datachanged: function( store ) {
                            var toolbar = Ext.getCmp('feature_export_toolbar');
                            var label = Ext.getCmp('feature_export_toolbar_disabled_label');
                            if( store.getTotalCount() <= maximum_export_size ) {
                                // enable the export toolbar
                                toolbar.enable();
                                label.hide();
                            } else {
                                // disable the export toolbar
                                toolbar.disable();
                                label.show();
                            }
                        }
                },

                proxy: {
                    type: 'ajax',
                    url: '/search/features/search_service',
                    timeout: 60000,
                    reader: {
                        root: 'data',
                        totalProperty: 'totalCount',
                        successProperty: 'success'
                    },
                    // sends single sort as multi parameter
                    simpleSortMode: true
                },
                sorters: [{
                     property: 'feature_id',
                     direction: 'ASC'
                }]
            });

            function hyphen_if_empty( value ) {
                return value.length > 0 ? value : '-';
            }

            function export_to_bulk( bulk_url ) {
                var search_query = get_search_query( feature_store );
                search_query.fields = 'name';
                Ext.Ajax.request({
                    url: '/search/features/search_service',
                    method: 'GET',
                    params: search_query,
                    success: function( response ) {
                        // make a bulk-download URL populated with these IDs
                        var features = Ext.JSON.decode( response.responseText ).data;
                        var names = [];
                        for( var i = 0; i < features.length; i++ ) {
                            names.push( features[i].name );
                        }
                        names = names.join("\n");

                        Ext.create( 'Ext.form.Panel', {
                          url: bulk_url,
                          standardSubmit: true,
                          defaultType: 'textfield',
                          hidden: true,
                          items: [{ name: 'ids', value: names }]
                        }).submit();
                    }
                 });
            }

            var feature_grid = Ext.create('Ext.grid.Panel', {
                width:    700,
                height:   400,
                //title:    'Matching Features',
                store:    feature_store,
                loadMask: true,

                dockedItems: [
                   {
                    xtype: 'toolbar',
                    dock: 'top',
                    id: 'feature_export_toolbar',
                    items: [
                        '->',
                        { xtype: 'label',
                          id: 'feature_export_toolbar_disabled_label',
                          text: 'Exporting limited to '+ Ext.util.Format.number( maximum_export_size, '0,000' )+' features.',
                          hidden: true
                        },{
                            xtype: 'button',
                            text: 'Save as',
                            icon: '/img/icons/oxygen/16x16/media-floppy.png',
                            menu: {
                                items: [
                                    {
                                        text: 'CSV',
                                        icon: '/img/icons/oxygen/16x16/text-csv.png',
                                        handler: function() {
                                            var search_query_vars = get_search_query( feature_store );
                                            var csv_url = '/search/features/export_csv?' + Ext.Object.toQueryString( search_query_vars );
                                            location.href = csv_url;
                                        }
                                    }
                                ]
                            }
                        },{
                            xtype: 'button',
                            text: 'Send to',
                            icon: '/img/icons/oxygen/16x16/document-export.png',
                            menu: {
                                items: [
                                    {
                                        text: 'bulk feature download',
                                        icon: '/img/icons/oxygen/16x16/document-export-table.png',
                                        handler: function() {
                                            export_to_bulk( '/bulk/feature' );
                                        }
                                    },{
                                        text: 'bulk gene download',
                                        icon: '/img/icons/oxygen/16x16/document-export-table.png',
                                        handler: function() {
                                            export_to_bulk( '/bulk/gene' );
                                        }
                                    }
                                ]
                            }
                        }
                    ]
                   },{
                    xtype: 'pagingtoolbar',
                    store: feature_store,   // same store GridPanel is using
                    dock: 'bottom',
                    displayInfo: true,
                    emptyMsg: 'No matching features'
                   }
                ],

                viewConfig: {
                    trackOver: false
                },
                // grid columns
                columns:[
                {
                    id: 'organism',
                    text: "Organism",
                    dataIndex: 'organism',
                    width: 150,
                    sortable: true,
                    flex: 1
                },{
                    text: "Type",
                    dataIndex: 'type',
                    width: 90,
                    hidden: false,
                    sortable: true
                },{
                    text: "Name",
                    dataIndex: 'name',
                    align: 'center',
                    width: 150,
                    sortable: true,
                    flex: 1,
                    renderer: function(value,p,record) {
                        return Ext.String.format(
                            '<a href="/feature/{0}/details" target="_blank">{1}</a>',
                            record.getId(),
                            value
                         );
                    }
                },{
                    text: "Description",
                    dataIndex: 'description',
                    align: 'left',
                    width: 200,
                    sortable: false,
                    flex: 1,
                    renderer: hyphen_if_empty
                },{
                    text: "Location(s)",
                    dataIndex: 'locations',
                    align: 'left',
                    width: 200,
                    sortable: false,
                    flex: 1,
                    renderer: hyphen_if_empty
                }
                ],
                renderTo: document.getElementById('search_grid')
            });

            // make the form for feature filtering
            var feature_types_store =
                Ext.create('Ext.data.Store', {
                          fields: ['type_id', 'name'],
                          proxy: {
                              type: 'ajax',
                              timeout: 60000,
                              url: '/search/features/feature_types_service',
                              reader: {
                                  root: 'data',
                                  totalProperty: 'totalCount',
                                  successProperty: 'success'
                              }
                          }
                      });

            var featureprop_types_store =
                Ext.create('Ext.data.Store', {
                          fields: ['type_id', 'name'],
                          proxy: {
                              type: 'ajax',
                              timeout: 60000,
                              url: '/search/features/featureprop_types_service',
                              reader: {
                                  root: 'data',
                                  totalProperty: 'totalCount',
                                  successProperty: 'success'
                              }
                          }
                      });

            var srcfeatures_store =
                 Ext.create('Ext.data.Store', {
                          model: 'Feature',
                          proxy: {
                              type: 'ajax',
                              timeout: 60000,
                              url:  '/search/features/srcfeatures_service',
                              reader: {
                                  root: 'data',
                                  totalProperty:   'totalCount',
                                  successProperty: 'success'
                              }
                          }
                      });

            function applyFeatureFilters( form ) {
                var data = form.getFieldValues();
                // filter out any form fields that are just whitespace
                for( var name in data ) {
                    if( data[name] == null || typeof data[name] == 'string' && ! data[name].match(/[^\s]/) ) {
                        delete data[name];
                    }
                }
                feature_store.proxy.extraParams = data;
                feature_store.load( function(records,operation,success) {
                    if( ! success ) {
                      feature_store.removeAll();
                    }
                });
            };

            // default field settings for the text fields that make the
            // enter key submit the form

            var feature_search_field_defaults = {
                          maxLength: 100,
                          width: 425,
                          labelWidth: 130,
                          listeners: {
                              specialkey: function(field, e){
                                  if (e.getKey() == e.ENTER) {
                                      applyFeatureFilters( field.up('form').getForm() );
                                  }
                              }
                          }
            };

            var feature_filter_form = Ext.create('Ext.form.Panel', {
                  width: 450,
                  bodyPadding: 10,
                  defaultType: 'textfield',
                  renderTo: document.getElementById('search_form'),
                  items: [
                      {
                          fieldLabel: 'Name contains',
                          name: 'name'
                      },
                      {
                          fieldLabel: 'Organism contains',
                          name: 'organism'
                      },
                      {
                          xtype: 'combobox',
                          fieldLabel: 'Type is',
                          id: 'feature_type_select',
                          name: 'type_id',
                          store: feature_types_store,
                          disabled: true, // enabled when feature_types_store finishes loading
                          queryMode: 'local',
                          displayField: 'name',
                          valueField: 'type_id',
                          typeAhead: true,
                          listeners: {} // don't override the combobox's enter key
                      },
                      {
                          fieldLabel: 'Description contains',
                          name: 'description'
                      },
                      {
                          xtype: 'fieldset',
                          title: 'Overlaps range',
                          width: 425,
                          layout: 'hbox',
                          defaults: feature_search_field_defaults,
                          items: [
                              {
                                xtype: 'combobox',
                                name:  'srcfeature_id',
                                store: srcfeatures_store,
                                disabled: true, // enabled when srcfeatures_store finishes load
                                id: 'srcfeature_select',
                                queryMode: 'local',
                                displayField: 'name',
                                valueField: 'feature_id',
                                width: 200,
                                listeners: {
                                    // when the srcfeature is set, set the
                                    // max values of the range numbers to
                                    // the srcfeature's length
                                    change: function( cbox, newValue, oldValue ) {
                                        var feature = cbox.getStore().getById( newValue );
                                        if( feature ) {
                                             var len = feature.raw.seqlen;
                                             var srcfeature_start = Ext.getCmp('srcfeature_start');
                                             var srcfeature_end = Ext.getCmp('srcfeature_end');
                                             srcfeature_start.setMaxValue( len );
                                             srcfeature_end.setMaxValue( len );
                                             if( ! srcfeature_start.getValue() )
                                                 srcfeature_start.setValue( 1 );
                                             if( ! srcfeature_end.getValue() || srcfeature_end.getValue() > len )
                                                 srcfeature_end.setValue( len );
                                        }
                                    }
                                }
                              },
                              { xtype: 'numberfield',
                                id: 'srcfeature_start',
                                name: 'srcfeature_start',
                                step: 10000,
                                minValue: 1,
                                width: 100
                              },
                              { xtype: 'numberfield',
                                id: 'srcfeature_end',
                                name: 'srcfeature_end',
                                step: 10000,
                                minValue: 1,
                                width: 100
                              }
                          ]
                      },
                      {
                          xtype: 'fieldset',
                          title: 'Has property',
                          width: 425,
                          layout: 'hbox',
                          defaultType: 'textfield',
                          defaults: feature_search_field_defaults,
                          items: [
                            {
                              xtype: 'combobox',
                              name: 'proptype_id',
                              id: 'featureprop_type_select',
                              width: 200,
                              store: featureprop_types_store,
                              disabled: true, // enabled when featureprop_types_store finishes loading
                              queryMode: 'local',
                              displayField: 'name',
                              valueField: 'type_id',
                              typeAhead: true,
                              listeners: {} // don't override the combobox's enter key
                            },{
                              fieldLabel: 'containing',
                              labelWidth: 75,
                              labelAlign: 'right',
                              name: 'prop_value',
                              width: 200
                            }
                          ]
                      }
                    ],
                    // make the ENTER key submit the form by default for all form fields
                    defaults: feature_search_field_defaults,
                    buttons: [
                        {
                            text: 'Clear',
                            handler: function() {
                                var form = this.up('form').getForm();
                                form.reset();
                            }
                        },{
                            text: 'Apply',
                            handler: function() {
                                applyFeatureFilters( this.up('form').getForm() );
                            }
                        }
                    ]
                });


                // only enable the various comboboxes in the filtering
                // form when their associated data stores finish
                // loading.
                feature_types_store.load(
                    function( recs, op, success ) {
                        if( success ) Ext.getCmp('feature_type_select').enable();
                    }
                );
                featureprop_types_store.load(
                    function( recs, op, success ) {
                        if( success ) Ext.getCmp('featureprop_type_select').enable();
                    }
                );
                srcfeatures_store.load(
                    function( recs, op, success ) {
                        if( success ) Ext.getCmp('srcfeature_select').enable();
                    }
                );

            });
    }
};

