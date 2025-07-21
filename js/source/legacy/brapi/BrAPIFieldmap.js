(function (global, factory) {
	typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('d3'), require('leaflet')) :
	typeof define === 'function' && define.amd ? define(['d3', 'leaflet'], factory) :
	(global.BrAPIFieldmap = factory(global.d3,global.L));
}(this, (function (d3,L) { 'use strict';

	d3 = d3 && d3.hasOwnProperty('default') ? d3['default'] : d3;
	L = L && L.hasOwnProperty('default') ? L['default'] : L;

	/*
	 Modified to explicitly use window.L
	*/
	/**
	 * Leaflet.TileLayer.Fallback 1.0.4+e36cde9
	 * Replaces missing Tiles (404 error) by scaled lower zoom Tiles
	 * (c) 2015-2018 Boris Seang
	 * License Apache-2.0
	 */
	(function (root, factory) {
	    if (typeof define === "function" && define.amd) {
	        define(["leaflet"], factory);
	    } else if (typeof module === "object" && module.exports) {
	        factory(require("leaflet"));
	    } else {
	        factory(window.L);
	    }
	}(undefined, function (L$$1) {

	L$$1.TileLayer.Fallback = L$$1.TileLayer.extend({

		options: {
			minNativeZoom: 0
		},

		initialize: function (urlTemplate, options) {
			L$$1.TileLayer.prototype.initialize.call(this, urlTemplate, options);
		},

		createTile: function (coords, done) {
			var tile = L$$1.TileLayer.prototype.createTile.call(this, coords, done);
			tile._originalCoords = coords;
			tile._originalSrc = tile.src;

			return tile;
		},

		_createCurrentCoords: function (originalCoords) {
			var currentCoords = this._wrapCoords(originalCoords);

			currentCoords.fallback = true;

			return currentCoords;
		},

		_originalTileOnError: L$$1.TileLayer.prototype._tileOnError,

		_tileOnError: function (done, tile, e) {
			var layer = this, // `this` is bound to the Tile Layer in L.TileLayer.prototype.createTile.
			    originalCoords = tile._originalCoords,
			    currentCoords = tile._currentCoords = tile._currentCoords || layer._createCurrentCoords(originalCoords),
			    fallbackZoom = tile._fallbackZoom = tile._fallbackZoom === undefined ? originalCoords.z - 1 : tile._fallbackZoom - 1,
			    scale = tile._fallbackScale = (tile._fallbackScale || 1) * 2,
			    tileSize = layer.getTileSize(),
			    style = tile.style,
			    newUrl, top, left;

			// If no lower zoom tiles are available, fallback to errorTile.
			if (fallbackZoom < layer.options.minNativeZoom) {
				return this._originalTileOnError(done, tile, e);
			}

			// Modify tilePoint for replacement img.
			currentCoords.z = fallbackZoom;
			currentCoords.x = Math.floor(currentCoords.x / 2);
			currentCoords.y = Math.floor(currentCoords.y / 2);

			// Generate new src path.
			newUrl = layer.getTileUrl(currentCoords);

			// Zoom replacement img.
			style.width = (tileSize.x * scale) + 'px';
			style.height = (tileSize.y * scale) + 'px';

			// Compute margins to adjust position.
			top = (originalCoords.y - currentCoords.y * scale) * tileSize.y;
			style.marginTop = (-top) + 'px';
			left = (originalCoords.x - currentCoords.x * scale) * tileSize.x;
			style.marginLeft = (-left) + 'px';

			// Crop (clip) image.
			// `clip` is deprecated, but browsers support for `clip-path: inset()` is far behind.
			// http://caniuse.com/#feat=css-clip-path
			style.clip = 'rect(' + top + 'px ' + (left + tileSize.x) + 'px ' + (top + tileSize.y) + 'px ' + left + 'px)';

			layer.fire('tilefallback', {
				tile: tile,
				url: tile._originalSrc,
				urlMissing: tile.src,
				urlFallback: newUrl
			});

			tile.src = newUrl;
		},

		getTileUrl: function (coords) {
			var z = coords.z = coords.fallback ? coords.z : this._getZoomForUrl();

			var data = {
				r: L$$1.Browser.retina ? '@2x' : '',
				s: this._getSubdomain(coords),
				x: coords.x,
				y: coords.y,
				z: z
			};
			if (this._map && !this._map.options.crs.infinite) {
				var invertedY = this._globalTileRange.max.y - coords.y;
				if (this.options.tms) {
					data['y'] = invertedY;
				}
				data['-y'] = invertedY;
			}

			return L$$1.Util.template(this._url, L$$1.extend(data, this.options));
		}

	});



	// Supply with a factory for consistency with Leaflet.
	L$$1.tileLayer.fallback = function (urlTemplate, options) {
		return new L$$1.TileLayer.Fallback(urlTemplate, options);
	};



	}));

	(function (factory, window) {
	    /*globals define, module, require*/

	    // define an AMD module that relies on 'leaflet'
	    if (typeof define === 'function' && define.amd) {
	        define(['leaflet'], factory);


	    // define a Common JS module that relies on 'leaflet'
	    } else if (typeof exports === 'object') {
	        module.exports = factory(require('leaflet'));
	    }

	    // attach your plugin to the global 'L' variable
	    if(typeof window !== 'undefined' && window.L){
	        factory(window.L);
	    }

	}(function (L$$1) {
	    // 🍂miniclass CancelableEvent (Event objects)
	    // 🍂method cancel()
	    // Cancel any subsequent action.

	    // 🍂miniclass VertexEvent (Event objects)
	    // 🍂property vertex: VertexMarker
	    // The vertex that fires the event.

	    // 🍂miniclass ShapeEvent (Event objects)
	    // 🍂property shape: Array
	    // The shape (LatLngs array) subject of the action.

	    // 🍂miniclass CancelableVertexEvent (Event objects)
	    // 🍂inherits VertexEvent
	    // 🍂inherits CancelableEvent

	    // 🍂miniclass CancelableShapeEvent (Event objects)
	    // 🍂inherits ShapeEvent
	    // 🍂inherits CancelableEvent

	    // 🍂miniclass LayerEvent (Event objects)
	    // 🍂property layer: object
	    // The Layer (Marker, Polyline…) subject of the action.

	    // 🍂namespace Editable; 🍂class Editable; 🍂aka L.Editable
	    // Main edition handler. By default, it is attached to the map
	    // as `map.editTools` property.
	    // Leaflet.Editable is made to be fully extendable. You have three ways to customize
	    // the behaviour: using options, listening to events, or extending.
	    L$$1.Editable = L$$1.Evented.extend({

	        statics: {
	            FORWARD: 1,
	            BACKWARD: -1
	        },

	        options: {

	            // You can pass them when creating a map using the `editOptions` key.
	            // 🍂option zIndex: int = 1000
	            // The default zIndex of the editing tools.
	            zIndex: 1000,

	            // 🍂option polygonClass: class = L.Polygon
	            // Class to be used when creating a new Polygon.
	            polygonClass: L$$1.Polygon,

	            // 🍂option polylineClass: class = L.Polyline
	            // Class to be used when creating a new Polyline.
	            polylineClass: L$$1.Polyline,

	            // 🍂option markerClass: class = L.Marker
	            // Class to be used when creating a new Marker.
	            markerClass: L$$1.Marker,

	            // 🍂option rectangleClass: class = L.Rectangle
	            // Class to be used when creating a new Rectangle.
	            rectangleClass: L$$1.Rectangle,

	            // 🍂option circleClass: class = L.Circle
	            // Class to be used when creating a new Circle.
	            circleClass: L$$1.Circle,

	            // 🍂option drawingCSSClass: string = 'leaflet-editable-drawing'
	            // CSS class to be added to the map container while drawing.
	            drawingCSSClass: 'leaflet-editable-drawing',

	            // 🍂option drawingCursor: const = 'crosshair'
	            // Cursor mode set to the map while drawing.
	            drawingCursor: 'crosshair',

	            // 🍂option editLayer: Layer = new L.LayerGroup()
	            // Layer used to store edit tools (vertex, line guide…).
	            editLayer: undefined,

	            // 🍂option featuresLayer: Layer = new L.LayerGroup()
	            // Default layer used to store drawn features (Marker, Polyline…).
	            featuresLayer: undefined,

	            // 🍂option polylineEditorClass: class = PolylineEditor
	            // Class to be used as Polyline editor.
	            polylineEditorClass: undefined,

	            // 🍂option polygonEditorClass: class = PolygonEditor
	            // Class to be used as Polygon editor.
	            polygonEditorClass: undefined,

	            // 🍂option markerEditorClass: class = MarkerEditor
	            // Class to be used as Marker editor.
	            markerEditorClass: undefined,

	            // 🍂option rectangleEditorClass: class = RectangleEditor
	            // Class to be used as Rectangle editor.
	            rectangleEditorClass: undefined,

	            // 🍂option circleEditorClass: class = CircleEditor
	            // Class to be used as Circle editor.
	            circleEditorClass: undefined,

	            // 🍂option lineGuideOptions: hash = {}
	            // Options to be passed to the line guides.
	            lineGuideOptions: {},

	            // 🍂option skipMiddleMarkers: boolean = false
	            // Set this to true if you don't want middle markers.
	            skipMiddleMarkers: false

	        },

	        initialize: function (map, options) {
	            L$$1.setOptions(this, options);
	            this._lastZIndex = this.options.zIndex;
	            this.map = map;
	            this.editLayer = this.createEditLayer();
	            this.featuresLayer = this.createFeaturesLayer();
	            this.forwardLineGuide = this.createLineGuide();
	            this.backwardLineGuide = this.createLineGuide();
	        },

	        fireAndForward: function (type, e) {
	            e = e || {};
	            e.editTools = this;
	            this.fire(type, e);
	            this.map.fire(type, e);
	        },

	        createLineGuide: function () {
	            var options = L$$1.extend({dashArray: '5,10', weight: 1, interactive: false}, this.options.lineGuideOptions);
	            return L$$1.polyline([], options);
	        },

	        createVertexIcon: function (options) {
	            return L$$1.Browser.mobile && L$$1.Browser.touch ? new L$$1.Editable.TouchVertexIcon(options) : new L$$1.Editable.VertexIcon(options);
	        },

	        createEditLayer: function () {
	            return this.options.editLayer || new L$$1.LayerGroup().addTo(this.map);
	        },

	        createFeaturesLayer: function () {
	            return this.options.featuresLayer || new L$$1.LayerGroup().addTo(this.map);
	        },

	        moveForwardLineGuide: function (latlng) {
	            if (this.forwardLineGuide._latlngs.length) {
	                this.forwardLineGuide._latlngs[1] = latlng;
	                this.forwardLineGuide._bounds.extend(latlng);
	                this.forwardLineGuide.redraw();
	            }
	        },

	        moveBackwardLineGuide: function (latlng) {
	            if (this.backwardLineGuide._latlngs.length) {
	                this.backwardLineGuide._latlngs[1] = latlng;
	                this.backwardLineGuide._bounds.extend(latlng);
	                this.backwardLineGuide.redraw();
	            }
	        },

	        anchorForwardLineGuide: function (latlng) {
	            this.forwardLineGuide._latlngs[0] = latlng;
	            this.forwardLineGuide._bounds.extend(latlng);
	            this.forwardLineGuide.redraw();
	        },

	        anchorBackwardLineGuide: function (latlng) {
	            this.backwardLineGuide._latlngs[0] = latlng;
	            this.backwardLineGuide._bounds.extend(latlng);
	            this.backwardLineGuide.redraw();
	        },

	        attachForwardLineGuide: function () {
	            this.editLayer.addLayer(this.forwardLineGuide);
	        },

	        attachBackwardLineGuide: function () {
	            this.editLayer.addLayer(this.backwardLineGuide);
	        },

	        detachForwardLineGuide: function () {
	            this.forwardLineGuide.setLatLngs([]);
	            this.editLayer.removeLayer(this.forwardLineGuide);
	        },

	        detachBackwardLineGuide: function () {
	            this.backwardLineGuide.setLatLngs([]);
	            this.editLayer.removeLayer(this.backwardLineGuide);
	        },

	        blockEvents: function () {
	            // Hack: force map not to listen to other layers events while drawing.
	            if (!this._oldTargets) {
	                this._oldTargets = this.map._targets;
	                this.map._targets = {};
	            }
	        },

	        unblockEvents: function () {
	            if (this._oldTargets) {
	                // Reset, but keep targets created while drawing.
	                this.map._targets = L$$1.extend(this.map._targets, this._oldTargets);
	                delete this._oldTargets;
	            }
	        },

	        registerForDrawing: function (editor) {
	            if (this._drawingEditor) this.unregisterForDrawing(this._drawingEditor);
	            this.blockEvents();
	            editor.reset();  // Make sure editor tools still receive events.
	            this._drawingEditor = editor;
	            this.map.on('mousemove touchmove', editor.onDrawingMouseMove, editor);
	            this.map.on('mousedown', this.onMousedown, this);
	            this.map.on('mouseup', this.onMouseup, this);
	            L$$1.DomUtil.addClass(this.map._container, this.options.drawingCSSClass);
	            this.defaultMapCursor = this.map._container.style.cursor;
	            this.map._container.style.cursor = this.options.drawingCursor;
	        },

	        unregisterForDrawing: function (editor) {
	            this.unblockEvents();
	            L$$1.DomUtil.removeClass(this.map._container, this.options.drawingCSSClass);
	            this.map._container.style.cursor = this.defaultMapCursor;
	            editor = editor || this._drawingEditor;
	            if (!editor) return;
	            this.map.off('mousemove touchmove', editor.onDrawingMouseMove, editor);
	            this.map.off('mousedown', this.onMousedown, this);
	            this.map.off('mouseup', this.onMouseup, this);
	            if (editor !== this._drawingEditor) return;
	            delete this._drawingEditor;
	            if (editor._drawing) editor.cancelDrawing();
	        },

	        onMousedown: function (e) {
	            if (e.originalEvent.which != 1) return;
	            this._mouseDown = e;
	            this._drawingEditor.onDrawingMouseDown(e);
	        },

	        onMouseup: function (e) {
	            if (this._mouseDown) {
	                var editor = this._drawingEditor,
	                    mouseDown = this._mouseDown;
	                this._mouseDown = null;
	                editor.onDrawingMouseUp(e);
	                if (this._drawingEditor !== editor) return;  // onDrawingMouseUp may call unregisterFromDrawing.
	                var origin = L$$1.point(mouseDown.originalEvent.clientX, mouseDown.originalEvent.clientY);
	                var distance = L$$1.point(e.originalEvent.clientX, e.originalEvent.clientY).distanceTo(origin);
	                if (Math.abs(distance) < 9 * (window.devicePixelRatio || 1)) this._drawingEditor.onDrawingClick(e);
	            }
	        },

	        // 🍂section Public methods
	        // You will generally access them by the `map.editTools`
	        // instance:
	        //
	        // `map.editTools.startPolyline();`

	        // 🍂method drawing(): boolean
	        // Return true if any drawing action is ongoing.
	        drawing: function () {
	            return this._drawingEditor && this._drawingEditor.drawing();
	        },

	        // 🍂method stopDrawing()
	        // When you need to stop any ongoing drawing, without needing to know which editor is active.
	        stopDrawing: function () {
	            this.unregisterForDrawing();
	        },

	        // 🍂method commitDrawing()
	        // When you need to commit any ongoing drawing, without needing to know which editor is active.
	        commitDrawing: function (e) {
	            if (!this._drawingEditor) return;
	            this._drawingEditor.commitDrawing(e);
	        },

	        connectCreatedToMap: function (layer) {
	            return this.featuresLayer.addLayer(layer);
	        },

	        // 🍂method startPolyline(latlng: L.LatLng, options: hash): L.Polyline
	        // Start drawing a Polyline. If `latlng` is given, a first point will be added. In any case, continuing on user click.
	        // If `options` is given, it will be passed to the Polyline class constructor.
	        startPolyline: function (latlng, options) {
	            var line = this.createPolyline([], options);
	            line.enableEdit(this.map).newShape(latlng);
	            return line;
	        },

	        // 🍂method startPolygon(latlng: L.LatLng, options: hash): L.Polygon
	        // Start drawing a Polygon. If `latlng` is given, a first point will be added. In any case, continuing on user click.
	        // If `options` is given, it will be passed to the Polygon class constructor.
	        startPolygon: function (latlng, options) {
	            var polygon = this.createPolygon([], options);
	            polygon.enableEdit(this.map).newShape(latlng);
	            return polygon;
	        },

	        // 🍂method startMarker(latlng: L.LatLng, options: hash): L.Marker
	        // Start adding a Marker. If `latlng` is given, the Marker will be shown first at this point.
	        // In any case, it will follow the user mouse, and will have a final `latlng` on next click (or touch).
	        // If `options` is given, it will be passed to the Marker class constructor.
	        startMarker: function (latlng, options) {
	            latlng = latlng || this.map.getCenter().clone();
	            var marker = this.createMarker(latlng, options);
	            marker.enableEdit(this.map).startDrawing();
	            return marker;
	        },

	        // 🍂method startRectangle(latlng: L.LatLng, options: hash): L.Rectangle
	        // Start drawing a Rectangle. If `latlng` is given, the Rectangle anchor will be added. In any case, continuing on user drag.
	        // If `options` is given, it will be passed to the Rectangle class constructor.
	        startRectangle: function(latlng, options) {
	            var corner = latlng || L$$1.latLng([0, 0]);
	            var bounds = new L$$1.LatLngBounds(corner, corner);
	            var rectangle = this.createRectangle(bounds, options);
	            rectangle.enableEdit(this.map).startDrawing();
	            return rectangle;
	        },

	        // 🍂method startCircle(latlng: L.LatLng, options: hash): L.Circle
	        // Start drawing a Circle. If `latlng` is given, the Circle anchor will be added. In any case, continuing on user drag.
	        // If `options` is given, it will be passed to the Circle class constructor.
	        startCircle: function (latlng, options) {
	            latlng = latlng || this.map.getCenter().clone();
	            var circle = this.createCircle(latlng, options);
	            circle.enableEdit(this.map).startDrawing();
	            return circle;
	        },

	        startHole: function (editor, latlng) {
	            editor.newHole(latlng);
	        },

	        createLayer: function (klass, latlngs, options) {
	            options = L$$1.Util.extend({editOptions: {editTools: this}}, options);
	            var layer = new klass(latlngs, options);
	            // 🍂namespace Editable
	            // 🍂event editable:created: LayerEvent
	            // Fired when a new feature (Marker, Polyline…) is created.
	            this.fireAndForward('editable:created', {layer: layer});
	            return layer;
	        },

	        createPolyline: function (latlngs, options) {
	            return this.createLayer(options && options.polylineClass || this.options.polylineClass, latlngs, options);
	        },

	        createPolygon: function (latlngs, options) {
	            return this.createLayer(options && options.polygonClass || this.options.polygonClass, latlngs, options);
	        },

	        createMarker: function (latlng, options) {
	            return this.createLayer(options && options.markerClass || this.options.markerClass, latlng, options);
	        },

	        createRectangle: function (bounds, options) {
	            return this.createLayer(options && options.rectangleClass || this.options.rectangleClass, bounds, options);
	        },

	        createCircle: function (latlng, options) {
	            return this.createLayer(options && options.circleClass || this.options.circleClass, latlng, options);
	        }

	    });

	    L$$1.extend(L$$1.Editable, {

	        makeCancellable: function (e) {
	            e.cancel = function () {
	                e._cancelled = true;
	            };
	        }

	    });

	    // 🍂namespace Map; 🍂class Map
	    // Leaflet.Editable add options and events to the `L.Map` object.
	    // See `Editable` events for the list of events fired on the Map.
	    // 🍂example
	    //
	    // ```js
	    // var map = L.map('map', {
	    //  editable: true,
	    //  editOptions: {
	    //    …
	    // }
	    // });
	    // ```
	    // 🍂section Editable Map Options
	    L$$1.Map.mergeOptions({

	        // 🍂namespace Map
	        // 🍂section Map Options
	        // 🍂option editToolsClass: class = L.Editable
	        // Class to be used as vertex, for path editing.
	        editToolsClass: L$$1.Editable,

	        // 🍂option editable: boolean = false
	        // Whether to create a L.Editable instance at map init.
	        editable: false,

	        // 🍂option editOptions: hash = {}
	        // Options to pass to L.Editable when instantiating.
	        editOptions: {}

	    });

	    L$$1.Map.addInitHook(function () {

	        this.whenReady(function () {
	            if (this.options.editable) {
	                this.editTools = new this.options.editToolsClass(this, this.options.editOptions);
	            }
	        });

	    });

	    L$$1.Editable.VertexIcon = L$$1.DivIcon.extend({

	        options: {
	            iconSize: new L$$1.Point(8, 8)
	        }

	    });

	    L$$1.Editable.TouchVertexIcon = L$$1.Editable.VertexIcon.extend({

	        options: {
	            iconSize: new L$$1.Point(20, 20)
	        }

	    });


	    // 🍂namespace Editable; 🍂class VertexMarker; Handler for dragging path vertices.
	    L$$1.Editable.VertexMarker = L$$1.Marker.extend({

	        options: {
	            draggable: true,
	            className: 'leaflet-div-icon leaflet-vertex-icon'
	        },


	        // 🍂section Public methods
	        // The marker used to handle path vertex. You will usually interact with a `VertexMarker`
	        // instance when listening for events like `editable:vertex:ctrlclick`.

	        initialize: function (latlng, latlngs, editor, options) {
	            // We don't use this._latlng, because on drag Leaflet replace it while
	            // we want to keep reference.
	            this.latlng = latlng;
	            this.latlngs = latlngs;
	            this.editor = editor;
	            L$$1.Marker.prototype.initialize.call(this, latlng, options);
	            this.options.icon = this.editor.tools.createVertexIcon({className: this.options.className});
	            this.latlng.__vertex = this;
	            this.editor.editLayer.addLayer(this);
	            this.setZIndexOffset(editor.tools._lastZIndex + 1);
	        },

	        onAdd: function (map) {
	            L$$1.Marker.prototype.onAdd.call(this, map);
	            this.on('drag', this.onDrag);
	            this.on('dragstart', this.onDragStart);
	            this.on('dragend', this.onDragEnd);
	            this.on('mouseup', this.onMouseup);
	            this.on('click', this.onClick);
	            this.on('contextmenu', this.onContextMenu);
	            this.on('mousedown touchstart', this.onMouseDown);
	            this.on('mouseover', this.onMouseOver);
	            this.on('mouseout', this.onMouseOut);
	            this.addMiddleMarkers();
	        },

	        onRemove: function (map) {
	            if (this.middleMarker) this.middleMarker.delete();
	            delete this.latlng.__vertex;
	            this.off('drag', this.onDrag);
	            this.off('dragstart', this.onDragStart);
	            this.off('dragend', this.onDragEnd);
	            this.off('mouseup', this.onMouseup);
	            this.off('click', this.onClick);
	            this.off('contextmenu', this.onContextMenu);
	            this.off('mousedown touchstart', this.onMouseDown);
	            this.off('mouseover', this.onMouseOver);
	            this.off('mouseout', this.onMouseOut);
	            L$$1.Marker.prototype.onRemove.call(this, map);
	        },

	        onDrag: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerDrag(e);
	            var iconPos = L$$1.DomUtil.getPosition(this._icon),
	                latlng = this._map.layerPointToLatLng(iconPos);
	            this.latlng.update(latlng);
	            this._latlng = this.latlng;  // Push back to Leaflet our reference.
	            this.editor.refresh();
	            if (this.middleMarker) this.middleMarker.updateLatLng();
	            var next = this.getNext();
	            if (next && next.middleMarker) next.middleMarker.updateLatLng();
	        },

	        onDragStart: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerDragStart(e);
	        },

	        onDragEnd: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerDragEnd(e);
	        },

	        onClick: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerClick(e);
	        },

	        onMouseup: function (e) {
	            L$$1.DomEvent.stop(e);
	            e.vertex = this;
	            this.editor.map.fire('mouseup', e);
	        },

	        onContextMenu: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerContextMenu(e);
	        },

	        onMouseDown: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerMouseDown(e);
	        },

	        onMouseOver: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerMouseOver(e);
	        },

	        onMouseOut: function (e) {
	            e.vertex = this;
	            this.editor.onVertexMarkerMouseOut(e);
	        },

	        // 🍂method delete()
	        // Delete a vertex and the related LatLng.
	        delete: function () {
	            var next = this.getNext();  // Compute before changing latlng
	            this.latlngs.splice(this.getIndex(), 1);
	            this.editor.editLayer.removeLayer(this);
	            this.editor.onVertexDeleted({latlng: this.latlng, vertex: this});
	            if (!this.latlngs.length) this.editor.deleteShape(this.latlngs);
	            if (next) next.resetMiddleMarker();
	            this.editor.refresh();
	        },

	        // 🍂method getIndex(): int
	        // Get the index of the current vertex among others of the same LatLngs group.
	        getIndex: function () {
	            return this.latlngs.indexOf(this.latlng);
	        },

	        // 🍂method getLastIndex(): int
	        // Get last vertex index of the LatLngs group of the current vertex.
	        getLastIndex: function () {
	            return this.latlngs.length - 1;
	        },

	        // 🍂method getPrevious(): VertexMarker
	        // Get the previous VertexMarker in the same LatLngs group.
	        getPrevious: function () {
	            if (this.latlngs.length < 2) return;
	            var index = this.getIndex(),
	                previousIndex = index - 1;
	            if (index === 0 && this.editor.CLOSED) previousIndex = this.getLastIndex();
	            var previous = this.latlngs[previousIndex];
	            if (previous) return previous.__vertex;
	        },

	        // 🍂method getNext(): VertexMarker
	        // Get the next VertexMarker in the same LatLngs group.
	        getNext: function () {
	            if (this.latlngs.length < 2) return;
	            var index = this.getIndex(),
	                nextIndex = index + 1;
	            if (index === this.getLastIndex() && this.editor.CLOSED) nextIndex = 0;
	            var next = this.latlngs[nextIndex];
	            if (next) return next.__vertex;
	        },

	        addMiddleMarker: function (previous) {
	            if (!this.editor.hasMiddleMarkers()) return;
	            previous = previous || this.getPrevious();
	            if (previous && !this.middleMarker) this.middleMarker = this.editor.addMiddleMarker(previous, this, this.latlngs, this.editor);
	        },

	        addMiddleMarkers: function () {
	            if (!this.editor.hasMiddleMarkers()) return;
	            var previous = this.getPrevious();
	            if (previous) this.addMiddleMarker(previous);
	            var next = this.getNext();
	            if (next) next.resetMiddleMarker();
	        },

	        resetMiddleMarker: function () {
	            if (this.middleMarker) this.middleMarker.delete();
	            this.addMiddleMarker();
	        },

	        // 🍂method split()
	        // Split the vertex LatLngs group at its index, if possible.
	        split: function () {
	            if (!this.editor.splitShape) return;  // Only for PolylineEditor
	            this.editor.splitShape(this.latlngs, this.getIndex());
	        },

	        // 🍂method continue()
	        // Continue the vertex LatLngs from this vertex. Only active for first and last vertices of a Polyline.
	        continue: function () {
	            if (!this.editor.continueBackward) return;  // Only for PolylineEditor
	            var index = this.getIndex();
	            if (index === 0) this.editor.continueBackward(this.latlngs);
	            else if (index === this.getLastIndex()) this.editor.continueForward(this.latlngs);
	        }

	    });

	    L$$1.Editable.mergeOptions({

	        // 🍂namespace Editable
	        // 🍂option vertexMarkerClass: class = VertexMarker
	        // Class to be used as vertex, for path editing.
	        vertexMarkerClass: L$$1.Editable.VertexMarker

	    });

	    L$$1.Editable.MiddleMarker = L$$1.Marker.extend({

	        options: {
	            opacity: 0.5,
	            className: 'leaflet-div-icon leaflet-middle-icon',
	            draggable: true
	        },

	        initialize: function (left, right, latlngs, editor, options) {
	            this.left = left;
	            this.right = right;
	            this.editor = editor;
	            this.latlngs = latlngs;
	            L$$1.Marker.prototype.initialize.call(this, this.computeLatLng(), options);
	            this._opacity = this.options.opacity;
	            this.options.icon = this.editor.tools.createVertexIcon({className: this.options.className});
	            this.editor.editLayer.addLayer(this);
	            this.setVisibility();
	        },

	        setVisibility: function () {
	            var leftPoint = this._map.latLngToContainerPoint(this.left.latlng),
	                rightPoint = this._map.latLngToContainerPoint(this.right.latlng),
	                size = L$$1.point(this.options.icon.options.iconSize);
	            if (leftPoint.distanceTo(rightPoint) < size.x * 3) this.hide();
	            else this.show();
	        },

	        show: function () {
	            this.setOpacity(this._opacity);
	        },

	        hide: function () {
	            this.setOpacity(0);
	        },

	        updateLatLng: function () {
	            this.setLatLng(this.computeLatLng());
	            this.setVisibility();
	        },

	        computeLatLng: function () {
	            var leftPoint = this.editor.map.latLngToContainerPoint(this.left.latlng),
	                rightPoint = this.editor.map.latLngToContainerPoint(this.right.latlng),
	                y = (leftPoint.y + rightPoint.y) / 2,
	                x = (leftPoint.x + rightPoint.x) / 2;
	            return this.editor.map.containerPointToLatLng([x, y]);
	        },

	        onAdd: function (map) {
	            L$$1.Marker.prototype.onAdd.call(this, map);
	            L$$1.DomEvent.on(this._icon, 'mousedown touchstart', this.onMouseDown, this);
	            map.on('zoomend', this.setVisibility, this);
	        },

	        onRemove: function (map) {
	            delete this.right.middleMarker;
	            L$$1.DomEvent.off(this._icon, 'mousedown touchstart', this.onMouseDown, this);
	            map.off('zoomend', this.setVisibility, this);
	            L$$1.Marker.prototype.onRemove.call(this, map);
	        },

	        onMouseDown: function (e) {
	            var iconPos = L$$1.DomUtil.getPosition(this._icon),
	                latlng = this.editor.map.layerPointToLatLng(iconPos);
	            e = {
	                originalEvent: e,
	                latlng: latlng
	            };
	            if (this.options.opacity === 0) return;
	            L$$1.Editable.makeCancellable(e);
	            this.editor.onMiddleMarkerMouseDown(e);
	            if (e._cancelled) return;
	            this.latlngs.splice(this.index(), 0, e.latlng);
	            this.editor.refresh();
	            var icon = this._icon;
	            var marker = this.editor.addVertexMarker(e.latlng, this.latlngs);
	            this.editor.onNewVertex(marker);
	            /* Hack to workaround browser not firing touchend when element is no more on DOM */
	            var parent = marker._icon.parentNode;
	            parent.removeChild(marker._icon);
	            marker._icon = icon;
	            parent.appendChild(marker._icon);
	            marker._initIcon();
	            marker._initInteraction();
	            marker.setOpacity(1);
	            /* End hack */
	            // Transfer ongoing dragging to real marker
	            L$$1.Draggable._dragging = false;
	            marker.dragging._draggable._onDown(e.originalEvent);
	            this.delete();
	        },

	        delete: function () {
	            this.editor.editLayer.removeLayer(this);
	        },

	        index: function () {
	            return this.latlngs.indexOf(this.right.latlng);
	        }

	    });

	    L$$1.Editable.mergeOptions({

	        // 🍂namespace Editable
	        // 🍂option middleMarkerClass: class = VertexMarker
	        // Class to be used as middle vertex, pulled by the user to create a new point in the middle of a path.
	        middleMarkerClass: L$$1.Editable.MiddleMarker

	    });

	    // 🍂namespace Editable; 🍂class BaseEditor; 🍂aka L.Editable.BaseEditor
	    // When editing a feature (Marker, Polyline…), an editor is attached to it. This
	    // editor basically knows how to handle the edition.
	    L$$1.Editable.BaseEditor = L$$1.Handler.extend({

	        initialize: function (map, feature, options) {
	            L$$1.setOptions(this, options);
	            this.map = map;
	            this.feature = feature;
	            this.feature.editor = this;
	            this.editLayer = new L$$1.LayerGroup();
	            this.tools = this.options.editTools || map.editTools;
	        },

	        // 🍂method enable(): this
	        // Set up the drawing tools for the feature to be editable.
	        addHooks: function () {
	            if (this.isConnected()) this.onFeatureAdd();
	            else this.feature.once('add', this.onFeatureAdd, this);
	            this.onEnable();
	            this.feature.on(this._getEvents(), this);
	        },

	        // 🍂method disable(): this
	        // Remove the drawing tools for the feature.
	        removeHooks: function () {
	            this.feature.off(this._getEvents(), this);
	            if (this.feature.dragging) this.feature.dragging.disable();
	            this.editLayer.clearLayers();
	            this.tools.editLayer.removeLayer(this.editLayer);
	            this.onDisable();
	            if (this._drawing) this.cancelDrawing();
	        },

	        // 🍂method drawing(): boolean
	        // Return true if any drawing action is ongoing with this editor.
	        drawing: function () {
	            return !!this._drawing;
	        },

	        reset: function () {},

	        onFeatureAdd: function () {
	            this.tools.editLayer.addLayer(this.editLayer);
	            if (this.feature.dragging) this.feature.dragging.enable();
	        },

	        hasMiddleMarkers: function () {
	            return !this.options.skipMiddleMarkers && !this.tools.options.skipMiddleMarkers;
	        },

	        fireAndForward: function (type, e) {
	            e = e || {};
	            e.layer = this.feature;
	            this.feature.fire(type, e);
	            this.tools.fireAndForward(type, e);
	        },

	        onEnable: function () {
	            // 🍂namespace Editable
	            // 🍂event editable:enable: Event
	            // Fired when an existing feature is ready to be edited.
	            this.fireAndForward('editable:enable');
	        },

	        onDisable: function () {
	            // 🍂namespace Editable
	            // 🍂event editable:disable: Event
	            // Fired when an existing feature is not ready anymore to be edited.
	            this.fireAndForward('editable:disable');
	        },

	        onEditing: function () {
	            // 🍂namespace Editable
	            // 🍂event editable:editing: Event
	            // Fired as soon as any change is made to the feature geometry.
	            this.fireAndForward('editable:editing');
	        },

	        onStartDrawing: function () {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:start: Event
	            // Fired when a feature is to be drawn.
	            this.fireAndForward('editable:drawing:start');
	        },

	        onEndDrawing: function () {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:end: Event
	            // Fired when a feature is not drawn anymore.
	            this.fireAndForward('editable:drawing:end');
	        },

	        onCancelDrawing: function () {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:cancel: Event
	            // Fired when user cancel drawing while a feature is being drawn.
	            this.fireAndForward('editable:drawing:cancel');
	        },

	        onCommitDrawing: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:commit: Event
	            // Fired when user finish drawing a feature.
	            this.fireAndForward('editable:drawing:commit', e);
	        },

	        onDrawingMouseDown: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:mousedown: Event
	            // Fired when user `mousedown` while drawing.
	            this.fireAndForward('editable:drawing:mousedown', e);
	        },

	        onDrawingMouseUp: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:mouseup: Event
	            // Fired when user `mouseup` while drawing.
	            this.fireAndForward('editable:drawing:mouseup', e);
	        },

	        startDrawing: function () {
	            if (!this._drawing) this._drawing = L$$1.Editable.FORWARD;
	            this.tools.registerForDrawing(this);
	            this.onStartDrawing();
	        },

	        commitDrawing: function (e) {
	            this.onCommitDrawing(e);
	            this.endDrawing();
	        },

	        cancelDrawing: function () {
	            // If called during a vertex drag, the vertex will be removed before
	            // the mouseup fires on it. This is a workaround. Maybe better fix is
	            // To have L.Draggable reset it's status on disable (Leaflet side).
	            L$$1.Draggable._dragging = false;
	            this.onCancelDrawing();
	            this.endDrawing();
	        },

	        endDrawing: function () {
	            this._drawing = false;
	            this.tools.unregisterForDrawing(this);
	            this.onEndDrawing();
	        },

	        onDrawingClick: function (e) {
	            if (!this.drawing()) return;
	            L$$1.Editable.makeCancellable(e);
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:click: CancelableEvent
	            // Fired when user `click` while drawing, before any internal action is being processed.
	            this.fireAndForward('editable:drawing:click', e);
	            if (e._cancelled) return;
	            if (!this.isConnected()) this.connect(e);
	            this.processDrawingClick(e);
	        },

	        isConnected: function () {
	            return this.map.hasLayer(this.feature);
	        },

	        connect: function () {
	            this.tools.connectCreatedToMap(this.feature);
	            this.tools.editLayer.addLayer(this.editLayer);
	        },

	        onMove: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:move: Event
	            // Fired when `move` mouse while drawing, while dragging a marker, and while dragging a vertex.
	            this.fireAndForward('editable:drawing:move', e);
	        },

	        onDrawingMouseMove: function (e) {
	            this.onMove(e);
	        },

	        _getEvents: function () {
	            return {
	                dragstart: this.onDragStart,
	                drag: this.onDrag,
	                dragend: this.onDragEnd,
	                remove: this.disable
	            };
	        },

	        onDragStart: function (e) {
	            this.onEditing();
	            // 🍂namespace Editable
	            // 🍂event editable:dragstart: Event
	            // Fired before a path feature is dragged.
	            this.fireAndForward('editable:dragstart', e);
	        },

	        onDrag: function (e) {
	            this.onMove(e);
	            // 🍂namespace Editable
	            // 🍂event editable:drag: Event
	            // Fired when a path feature is being dragged.
	            this.fireAndForward('editable:drag', e);
	        },

	        onDragEnd: function (e) {
	            // 🍂namespace Editable
	            // 🍂event editable:dragend: Event
	            // Fired after a path feature has been dragged.
	            this.fireAndForward('editable:dragend', e);
	        }

	    });

	    // 🍂namespace Editable; 🍂class MarkerEditor; 🍂aka L.Editable.MarkerEditor
	    // 🍂inherits BaseEditor
	    // Editor for Marker.
	    L$$1.Editable.MarkerEditor = L$$1.Editable.BaseEditor.extend({

	        onDrawingMouseMove: function (e) {
	            L$$1.Editable.BaseEditor.prototype.onDrawingMouseMove.call(this, e);
	            if (this._drawing) this.feature.setLatLng(e.latlng);
	        },

	        processDrawingClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Drawing events
	            // 🍂event editable:drawing:clicked: Event
	            // Fired when user `click` while drawing, after all internal actions.
	            this.fireAndForward('editable:drawing:clicked', e);
	            this.commitDrawing(e);
	        },

	        connect: function (e) {
	            // On touch, the latlng has not been updated because there is
	            // no mousemove.
	            if (e) this.feature._latlng = e.latlng;
	            L$$1.Editable.BaseEditor.prototype.connect.call(this, e);
	        }

	    });

	    // 🍂namespace Editable; 🍂class PathEditor; 🍂aka L.Editable.PathEditor
	    // 🍂inherits BaseEditor
	    // Base class for all path editors.
	    L$$1.Editable.PathEditor = L$$1.Editable.BaseEditor.extend({

	        CLOSED: false,
	        MIN_VERTEX: 2,

	        addHooks: function () {
	            L$$1.Editable.BaseEditor.prototype.addHooks.call(this);
	            if (this.feature) this.initVertexMarkers();
	            return this;
	        },

	        initVertexMarkers: function (latlngs) {
	            if (!this.enabled()) return;
	            latlngs = latlngs || this.getLatLngs();
	            if (isFlat(latlngs)) this.addVertexMarkers(latlngs);
	            else for (var i = 0; i < latlngs.length; i++) this.initVertexMarkers(latlngs[i]);
	        },

	        getLatLngs: function () {
	            return this.feature.getLatLngs();
	        },

	        // 🍂method reset()
	        // Rebuild edit elements (Vertex, MiddleMarker, etc.).
	        reset: function () {
	            this.editLayer.clearLayers();
	            this.initVertexMarkers();
	        },

	        addVertexMarker: function (latlng, latlngs) {
	            return new this.tools.options.vertexMarkerClass(latlng, latlngs, this);
	        },

	        onNewVertex: function (vertex) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:new: VertexEvent
	            // Fired when a new vertex is created.
	            this.fireAndForward('editable:vertex:new', {latlng: vertex.latlng, vertex: vertex});
	        },

	        addVertexMarkers: function (latlngs) {
	            for (var i = 0; i < latlngs.length; i++) {
	                this.addVertexMarker(latlngs[i], latlngs);
	            }
	        },

	        refreshVertexMarkers: function (latlngs) {
	            latlngs = latlngs || this.getDefaultLatLngs();
	            for (var i = 0; i < latlngs.length; i++) {
	                latlngs[i].__vertex.update();
	            }
	        },

	        addMiddleMarker: function (left, right, latlngs) {
	            return new this.tools.options.middleMarkerClass(left, right, latlngs, this);
	        },

	        onVertexMarkerClick: function (e) {
	            L$$1.Editable.makeCancellable(e);
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:click: CancelableVertexEvent
	            // Fired when a `click` is issued on a vertex, before any internal action is being processed.
	            this.fireAndForward('editable:vertex:click', e);
	            if (e._cancelled) return;
	            if (this.tools.drawing() && this.tools._drawingEditor !== this) return;
	            var index = e.vertex.getIndex(), commit;
	            if (e.originalEvent.ctrlKey) {
	                this.onVertexMarkerCtrlClick(e);
	            } else if (e.originalEvent.altKey) {
	                this.onVertexMarkerAltClick(e);
	            } else if (e.originalEvent.shiftKey) {
	                this.onVertexMarkerShiftClick(e);
	            } else if (e.originalEvent.metaKey) {
	                this.onVertexMarkerMetaKeyClick(e);
	            } else if (index === e.vertex.getLastIndex() && this._drawing === L$$1.Editable.FORWARD) {
	                if (index >= this.MIN_VERTEX - 1) commit = true;
	            } else if (index === 0 && this._drawing === L$$1.Editable.BACKWARD && this._drawnLatLngs.length >= this.MIN_VERTEX) {
	                commit = true;
	            } else if (index === 0 && this._drawing === L$$1.Editable.FORWARD && this._drawnLatLngs.length >= this.MIN_VERTEX && this.CLOSED) {
	                commit = true;  // Allow to close on first point also for polygons
	            } else {
	                this.onVertexRawMarkerClick(e);
	            }
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:clicked: VertexEvent
	            // Fired when a `click` is issued on a vertex, after all internal actions.
	            this.fireAndForward('editable:vertex:clicked', e);
	            if (commit) this.commitDrawing(e);
	        },

	        onVertexRawMarkerClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:rawclick: CancelableVertexEvent
	            // Fired when a `click` is issued on a vertex without any special key and without being in drawing mode.
	            this.fireAndForward('editable:vertex:rawclick', e);
	            if (e._cancelled) return;
	            if (!this.vertexCanBeDeleted(e.vertex)) return;
	            e.vertex.delete();
	        },

	        vertexCanBeDeleted: function (vertex) {
	            return vertex.latlngs.length > this.MIN_VERTEX;
	        },

	        onVertexDeleted: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:deleted: VertexEvent
	            // Fired after a vertex has been deleted by user.
	            this.fireAndForward('editable:vertex:deleted', e);
	        },

	        onVertexMarkerCtrlClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:ctrlclick: VertexEvent
	            // Fired when a `click` with `ctrlKey` is issued on a vertex.
	            this.fireAndForward('editable:vertex:ctrlclick', e);
	        },

	        onVertexMarkerShiftClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:shiftclick: VertexEvent
	            // Fired when a `click` with `shiftKey` is issued on a vertex.
	            this.fireAndForward('editable:vertex:shiftclick', e);
	        },

	        onVertexMarkerMetaKeyClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:metakeyclick: VertexEvent
	            // Fired when a `click` with `metaKey` is issued on a vertex.
	            this.fireAndForward('editable:vertex:metakeyclick', e);
	        },

	        onVertexMarkerAltClick: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:altclick: VertexEvent
	            // Fired when a `click` with `altKey` is issued on a vertex.
	            this.fireAndForward('editable:vertex:altclick', e);
	        },

	        onVertexMarkerContextMenu: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:contextmenu: VertexEvent
	            // Fired when a `contextmenu` is issued on a vertex.
	            this.fireAndForward('editable:vertex:contextmenu', e);
	        },

	        onVertexMarkerMouseDown: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:mousedown: VertexEvent
	            // Fired when user `mousedown` a vertex.
	            this.fireAndForward('editable:vertex:mousedown', e);
	        },

	        onVertexMarkerMouseOver: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:mouseover: VertexEvent
	            // Fired when a user's mouse enters the vertex
	            this.fireAndForward('editable:vertex:mouseover', e);
	        },

	        onVertexMarkerMouseOut: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:mouseout: VertexEvent
	            // Fired when a user's mouse leaves the vertex
	            this.fireAndForward('editable:vertex:mouseout', e);
	        },

	        onMiddleMarkerMouseDown: function (e) {
	            // 🍂namespace Editable
	            // 🍂section MiddleMarker events
	            // 🍂event editable:middlemarker:mousedown: VertexEvent
	            // Fired when user `mousedown` a middle marker.
	            this.fireAndForward('editable:middlemarker:mousedown', e);
	        },

	        onVertexMarkerDrag: function (e) {
	            this.onMove(e);
	            if (this.feature._bounds) this.extendBounds(e);
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:drag: VertexEvent
	            // Fired when a vertex is dragged by user.
	            this.fireAndForward('editable:vertex:drag', e);
	        },

	        onVertexMarkerDragStart: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:dragstart: VertexEvent
	            // Fired before a vertex is dragged by user.
	            this.fireAndForward('editable:vertex:dragstart', e);
	        },

	        onVertexMarkerDragEnd: function (e) {
	            // 🍂namespace Editable
	            // 🍂section Vertex events
	            // 🍂event editable:vertex:dragend: VertexEvent
	            // Fired after a vertex is dragged by user.
	            this.fireAndForward('editable:vertex:dragend', e);
	        },

	        setDrawnLatLngs: function (latlngs) {
	            this._drawnLatLngs = latlngs || this.getDefaultLatLngs();
	        },

	        startDrawing: function () {
	            if (!this._drawnLatLngs) this.setDrawnLatLngs();
	            L$$1.Editable.BaseEditor.prototype.startDrawing.call(this);
	        },

	        startDrawingForward: function () {
	            this.startDrawing();
	        },

	        endDrawing: function () {
	            this.tools.detachForwardLineGuide();
	            this.tools.detachBackwardLineGuide();
	            if (this._drawnLatLngs && this._drawnLatLngs.length < this.MIN_VERTEX) this.deleteShape(this._drawnLatLngs);
	            L$$1.Editable.BaseEditor.prototype.endDrawing.call(this);
	            delete this._drawnLatLngs;
	        },

	        addLatLng: function (latlng) {
	            if (this._drawing === L$$1.Editable.FORWARD) this._drawnLatLngs.push(latlng);
	            else this._drawnLatLngs.unshift(latlng);
	            this.feature._bounds.extend(latlng);
	            var vertex = this.addVertexMarker(latlng, this._drawnLatLngs);
	            this.onNewVertex(vertex);
	            this.refresh();
	        },

	        newPointForward: function (latlng) {
	            this.addLatLng(latlng);
	            this.tools.attachForwardLineGuide();
	            this.tools.anchorForwardLineGuide(latlng);
	        },

	        newPointBackward: function (latlng) {
	            this.addLatLng(latlng);
	            this.tools.anchorBackwardLineGuide(latlng);
	        },

	        // 🍂namespace PathEditor
	        // 🍂method push()
	        // Programmatically add a point while drawing.
	        push: function (latlng) {
	            if (!latlng) return console.error('L.Editable.PathEditor.push expect a valid latlng as parameter');
	            if (this._drawing === L$$1.Editable.FORWARD) this.newPointForward(latlng);
	            else this.newPointBackward(latlng);
	        },

	        removeLatLng: function (latlng) {
	            latlng.__vertex.delete();
	            this.refresh();
	        },

	        // 🍂method pop(): L.LatLng or null
	        // Programmatically remove last point (if any) while drawing.
	        pop: function () {
	            if (this._drawnLatLngs.length <= 1) return;
	            var latlng;
	            if (this._drawing === L$$1.Editable.FORWARD) latlng = this._drawnLatLngs[this._drawnLatLngs.length - 1];
	            else latlng = this._drawnLatLngs[0];
	            this.removeLatLng(latlng);
	            if (this._drawing === L$$1.Editable.FORWARD) this.tools.anchorForwardLineGuide(this._drawnLatLngs[this._drawnLatLngs.length - 1]);
	            else this.tools.anchorForwardLineGuide(this._drawnLatLngs[0]);
	            return latlng;
	        },

	        processDrawingClick: function (e) {
	            if (e.vertex && e.vertex.editor === this) return;
	            if (this._drawing === L$$1.Editable.FORWARD) this.newPointForward(e.latlng);
	            else this.newPointBackward(e.latlng);
	            this.fireAndForward('editable:drawing:clicked', e);
	        },

	        onDrawingMouseMove: function (e) {
	            L$$1.Editable.BaseEditor.prototype.onDrawingMouseMove.call(this, e);
	            if (this._drawing) {
	                this.tools.moveForwardLineGuide(e.latlng);
	                this.tools.moveBackwardLineGuide(e.latlng);
	            }
	        },

	        refresh: function () {
	            this.feature.redraw();
	            this.onEditing();
	        },

	        // 🍂namespace PathEditor
	        // 🍂method newShape(latlng?: L.LatLng)
	        // Add a new shape (Polyline, Polygon) in a multi, and setup up drawing tools to draw it;
	        // if optional `latlng` is given, start a path at this point.
	        newShape: function (latlng) {
	            var shape = this.addNewEmptyShape();
	            if (!shape) return;
	            this.setDrawnLatLngs(shape[0] || shape);  // Polygon or polyline
	            this.startDrawingForward();
	            // 🍂namespace Editable
	            // 🍂section Shape events
	            // 🍂event editable:shape:new: ShapeEvent
	            // Fired when a new shape is created in a multi (Polygon or Polyline).
	            this.fireAndForward('editable:shape:new', {shape: shape});
	            if (latlng) this.newPointForward(latlng);
	        },

	        deleteShape: function (shape, latlngs) {
	            var e = {shape: shape};
	            L$$1.Editable.makeCancellable(e);
	            // 🍂namespace Editable
	            // 🍂section Shape events
	            // 🍂event editable:shape:delete: CancelableShapeEvent
	            // Fired before a new shape is deleted in a multi (Polygon or Polyline).
	            this.fireAndForward('editable:shape:delete', e);
	            if (e._cancelled) return;
	            shape = this._deleteShape(shape, latlngs);
	            if (this.ensureNotFlat) this.ensureNotFlat();  // Polygon.
	            this.feature.setLatLngs(this.getLatLngs());  // Force bounds reset.
	            this.refresh();
	            this.reset();
	            // 🍂namespace Editable
	            // 🍂section Shape events
	            // 🍂event editable:shape:deleted: ShapeEvent
	            // Fired after a new shape is deleted in a multi (Polygon or Polyline).
	            this.fireAndForward('editable:shape:deleted', {shape: shape});
	            return shape;
	        },

	        _deleteShape: function (shape, latlngs) {
	            latlngs = latlngs || this.getLatLngs();
	            if (!latlngs.length) return;
	            var self = this,
	                inplaceDelete = function (latlngs, shape) {
	                    // Called when deleting a flat latlngs
	                    shape = latlngs.splice(0, Number.MAX_VALUE);
	                    return shape;
	                },
	                spliceDelete = function (latlngs, shape) {
	                    // Called when removing a latlngs inside an array
	                    latlngs.splice(latlngs.indexOf(shape), 1);
	                    if (!latlngs.length) self._deleteShape(latlngs);
	                    return shape;
	                };
	            if (latlngs === shape) return inplaceDelete(latlngs, shape);
	            for (var i = 0; i < latlngs.length; i++) {
	                if (latlngs[i] === shape) return spliceDelete(latlngs, shape);
	                else if (latlngs[i].indexOf(shape) !== -1) return spliceDelete(latlngs[i], shape);
	            }
	        },

	        // 🍂namespace PathEditor
	        // 🍂method deleteShapeAt(latlng: L.LatLng): Array
	        // Remove a path shape at the given `latlng`.
	        deleteShapeAt: function (latlng) {
	            var shape = this.feature.shapeAt(latlng);
	            if (shape) return this.deleteShape(shape);
	        },

	        // 🍂method appendShape(shape: Array)
	        // Append a new shape to the Polygon or Polyline.
	        appendShape: function (shape) {
	            this.insertShape(shape);
	        },

	        // 🍂method prependShape(shape: Array)
	        // Prepend a new shape to the Polygon or Polyline.
	        prependShape: function (shape) {
	            this.insertShape(shape, 0);
	        },

	        // 🍂method insertShape(shape: Array, index: int)
	        // Insert a new shape to the Polygon or Polyline at given index (default is to append).
	        insertShape: function (shape, index) {
	            this.ensureMulti();
	            shape = this.formatShape(shape);
	            if (typeof index === 'undefined') index = this.feature._latlngs.length;
	            this.feature._latlngs.splice(index, 0, shape);
	            this.feature.redraw();
	            if (this._enabled) this.reset();
	        },

	        extendBounds: function (e) {
	            this.feature._bounds.extend(e.vertex.latlng);
	        },

	        onDragStart: function (e) {
	            this.editLayer.clearLayers();
	            L$$1.Editable.BaseEditor.prototype.onDragStart.call(this, e);
	        },

	        onDragEnd: function (e) {
	            this.initVertexMarkers();
	            L$$1.Editable.BaseEditor.prototype.onDragEnd.call(this, e);
	        }

	    });

	    // 🍂namespace Editable; 🍂class PolylineEditor; 🍂aka L.Editable.PolylineEditor
	    // 🍂inherits PathEditor
	    L$$1.Editable.PolylineEditor = L$$1.Editable.PathEditor.extend({

	        startDrawingBackward: function () {
	            this._drawing = L$$1.Editable.BACKWARD;
	            this.startDrawing();
	        },

	        // 🍂method continueBackward(latlngs?: Array)
	        // Set up drawing tools to continue the line backward.
	        continueBackward: function (latlngs) {
	            if (this.drawing()) return;
	            latlngs = latlngs || this.getDefaultLatLngs();
	            this.setDrawnLatLngs(latlngs);
	            if (latlngs.length > 0) {
	                this.tools.attachBackwardLineGuide();
	                this.tools.anchorBackwardLineGuide(latlngs[0]);
	            }
	            this.startDrawingBackward();
	        },

	        // 🍂method continueForward(latlngs?: Array)
	        // Set up drawing tools to continue the line forward.
	        continueForward: function (latlngs) {
	            if (this.drawing()) return;
	            latlngs = latlngs || this.getDefaultLatLngs();
	            this.setDrawnLatLngs(latlngs);
	            if (latlngs.length > 0) {
	                this.tools.attachForwardLineGuide();
	                this.tools.anchorForwardLineGuide(latlngs[latlngs.length - 1]);
	            }
	            this.startDrawingForward();
	        },

	        getDefaultLatLngs: function (latlngs) {
	            latlngs = latlngs || this.feature._latlngs;
	            if (!latlngs.length || latlngs[0] instanceof L$$1.LatLng) return latlngs;
	            else return this.getDefaultLatLngs(latlngs[0]);
	        },

	        ensureMulti: function () {
	            if (this.feature._latlngs.length && isFlat(this.feature._latlngs)) {
	                this.feature._latlngs = [this.feature._latlngs];
	            }
	        },

	        addNewEmptyShape: function () {
	            if (this.feature._latlngs.length) {
	                var shape = [];
	                this.appendShape(shape);
	                return shape;
	            } else {
	                return this.feature._latlngs;
	            }
	        },

	        formatShape: function (shape) {
	            if (isFlat(shape)) return shape;
	            else if (shape[0]) return this.formatShape(shape[0]);
	        },

	        // 🍂method splitShape(latlngs?: Array, index: int)
	        // Split the given `latlngs` shape at index `index` and integrate new shape in instance `latlngs`.
	        splitShape: function (shape, index) {
	            if (!index || index >= shape.length - 1) return;
	            this.ensureMulti();
	            var shapeIndex = this.feature._latlngs.indexOf(shape);
	            if (shapeIndex === -1) return;
	            var first = shape.slice(0, index + 1),
	                second = shape.slice(index);
	            // We deal with reference, we don't want twice the same latlng around.
	            second[0] = L$$1.latLng(second[0].lat, second[0].lng, second[0].alt);
	            this.feature._latlngs.splice(shapeIndex, 1, first, second);
	            this.refresh();
	            this.reset();
	        }

	    });

	    // 🍂namespace Editable; 🍂class PolygonEditor; 🍂aka L.Editable.PolygonEditor
	    // 🍂inherits PathEditor
	    L$$1.Editable.PolygonEditor = L$$1.Editable.PathEditor.extend({

	        CLOSED: true,
	        MIN_VERTEX: 3,

	        newPointForward: function (latlng) {
	            L$$1.Editable.PathEditor.prototype.newPointForward.call(this, latlng);
	            if (!this.tools.backwardLineGuide._latlngs.length) this.tools.anchorBackwardLineGuide(latlng);
	            if (this._drawnLatLngs.length === 2) this.tools.attachBackwardLineGuide();
	        },

	        addNewEmptyHole: function (latlng) {
	            this.ensureNotFlat();
	            var latlngs = this.feature.shapeAt(latlng);
	            if (!latlngs) return;
	            var holes = [];
	            latlngs.push(holes);
	            return holes;
	        },

	        // 🍂method newHole(latlng?: L.LatLng, index: int)
	        // Set up drawing tools for creating a new hole on the Polygon. If the `latlng` param is given, a first point is created.
	        newHole: function (latlng) {
	            var holes = this.addNewEmptyHole(latlng);
	            if (!holes) return;
	            this.setDrawnLatLngs(holes);
	            this.startDrawingForward();
	            if (latlng) this.newPointForward(latlng);
	        },

	        addNewEmptyShape: function () {
	            if (this.feature._latlngs.length && this.feature._latlngs[0].length) {
	                var shape = [];
	                this.appendShape(shape);
	                return shape;
	            } else {
	                return this.feature._latlngs;
	            }
	        },

	        ensureMulti: function () {
	            if (this.feature._latlngs.length && isFlat(this.feature._latlngs[0])) {
	                this.feature._latlngs = [this.feature._latlngs];
	            }
	        },

	        ensureNotFlat: function () {
	            if (!this.feature._latlngs.length || isFlat(this.feature._latlngs)) this.feature._latlngs = [this.feature._latlngs];
	        },

	        vertexCanBeDeleted: function (vertex) {
	            var parent = this.feature.parentShape(vertex.latlngs),
	                idx = L$$1.Util.indexOf(parent, vertex.latlngs);
	            if (idx > 0) return true;  // Holes can be totally deleted without removing the layer itself.
	            return L$$1.Editable.PathEditor.prototype.vertexCanBeDeleted.call(this, vertex);
	        },

	        getDefaultLatLngs: function () {
	            if (!this.feature._latlngs.length) this.feature._latlngs.push([]);
	            return this.feature._latlngs[0];
	        },

	        formatShape: function (shape) {
	            // [[1, 2], [3, 4]] => must be nested
	            // [] => must be nested
	            // [[]] => is already nested
	            if (isFlat(shape) && (!shape[0] || shape[0].length !== 0)) return [shape];
	            else return shape;
	        }

	    });

	    // 🍂namespace Editable; 🍂class RectangleEditor; 🍂aka L.Editable.RectangleEditor
	    // 🍂inherits PathEditor
	    L$$1.Editable.RectangleEditor = L$$1.Editable.PathEditor.extend({

	        CLOSED: true,
	        MIN_VERTEX: 4,

	        options: {
	            skipMiddleMarkers: true
	        },

	        extendBounds: function (e) {
	            var index = e.vertex.getIndex(),
	                next = e.vertex.getNext(),
	                previous = e.vertex.getPrevious(),
	                oppositeIndex = (index + 2) % 4,
	                opposite = e.vertex.latlngs[oppositeIndex],
	                bounds = new L$$1.LatLngBounds(e.latlng, opposite);
	            // Update latlngs by hand to preserve order.
	            previous.latlng.update([e.latlng.lat, opposite.lng]);
	            next.latlng.update([opposite.lat, e.latlng.lng]);
	            this.updateBounds(bounds);
	            this.refreshVertexMarkers();
	        },

	        onDrawingMouseDown: function (e) {
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseDown.call(this, e);
	            this.connect();
	            var latlngs = this.getDefaultLatLngs();
	            // L.Polygon._convertLatLngs removes last latlng if it equals first point,
	            // which is the case here as all latlngs are [0, 0]
	            if (latlngs.length === 3) latlngs.push(e.latlng);
	            var bounds = new L$$1.LatLngBounds(e.latlng, e.latlng);
	            this.updateBounds(bounds);
	            this.updateLatLngs(bounds);
	            this.refresh();
	            this.reset();
	            // Stop dragging map.
	            // L.Draggable has two workflows:
	            // - mousedown => mousemove => mouseup
	            // - touchstart => touchmove => touchend
	            // Problem: L.Map.Tap does not allow us to listen to touchstart, so we only
	            // can deal with mousedown, but then when in a touch device, we are dealing with
	            // simulated events (actually simulated by L.Map.Tap), which are no more taken
	            // into account by L.Draggable.
	            // Ref.: https://github.com/Leaflet/Leaflet.Editable/issues/103
	            e.originalEvent._simulated = false;
	            this.map.dragging._draggable._onUp(e.originalEvent);
	            // Now transfer ongoing drag action to the bottom right corner.
	            // Should we refine which corner will handle the drag according to
	            // drag direction?
	            latlngs[3].__vertex.dragging._draggable._onDown(e.originalEvent);
	        },

	        onDrawingMouseUp: function (e) {
	            this.commitDrawing(e);
	            e.originalEvent._simulated = false;
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseUp.call(this, e);
	        },

	        onDrawingMouseMove: function (e) {
	            e.originalEvent._simulated = false;
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseMove.call(this, e);
	        },


	        getDefaultLatLngs: function (latlngs) {
	            return latlngs || this.feature._latlngs[0];
	        },

	        updateBounds: function (bounds) {
	            this.feature._bounds = bounds;
	        },

	        updateLatLngs: function (bounds) {
	            var latlngs = this.getDefaultLatLngs(),
	                newLatlngs = this.feature._boundsToLatLngs(bounds);
	            // Keep references.
	            for (var i = 0; i < latlngs.length; i++) {
	                latlngs[i].update(newLatlngs[i]);
	            }
	        }

	    });

	    // 🍂namespace Editable; 🍂class CircleEditor; 🍂aka L.Editable.CircleEditor
	    // 🍂inherits PathEditor
	    L$$1.Editable.CircleEditor = L$$1.Editable.PathEditor.extend({

	        MIN_VERTEX: 2,

	        options: {
	            skipMiddleMarkers: true
	        },

	        initialize: function (map, feature, options) {
	            L$$1.Editable.PathEditor.prototype.initialize.call(this, map, feature, options);
	            this._resizeLatLng = this.computeResizeLatLng();
	        },

	        computeResizeLatLng: function () {
	            // While circle is not added to the map, _radius is not set.
	            var delta = (this.feature._radius || this.feature._mRadius) * Math.cos(Math.PI / 4),
	                point = this.map.project(this.feature._latlng);
	            return this.map.unproject([point.x + delta, point.y - delta]);
	        },

	        updateResizeLatLng: function () {
	            this._resizeLatLng.update(this.computeResizeLatLng());
	            this._resizeLatLng.__vertex.update();
	        },

	        getLatLngs: function () {
	            return [this.feature._latlng, this._resizeLatLng];
	        },

	        getDefaultLatLngs: function () {
	            return this.getLatLngs();
	        },

	        onVertexMarkerDrag: function (e) {
	            if (e.vertex.getIndex() === 1) this.resize(e);
	            else this.updateResizeLatLng(e);
	            L$$1.Editable.PathEditor.prototype.onVertexMarkerDrag.call(this, e);
	        },

	        resize: function (e) {
	            var radius = this.feature._latlng.distanceTo(e.latlng);
	            this.feature.setRadius(radius);
	        },

	        onDrawingMouseDown: function (e) {
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseDown.call(this, e);
	            this._resizeLatLng.update(e.latlng);
	            this.feature._latlng.update(e.latlng);
	            this.connect();
	            // Stop dragging map.
	            e.originalEvent._simulated = false;
	            this.map.dragging._draggable._onUp(e.originalEvent);
	            // Now transfer ongoing drag action to the radius handler.
	            this._resizeLatLng.__vertex.dragging._draggable._onDown(e.originalEvent);
	        },

	        onDrawingMouseUp: function (e) {
	            this.commitDrawing(e);
	            e.originalEvent._simulated = false;
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseUp.call(this, e);
	        },

	        onDrawingMouseMove: function (e) {
	            e.originalEvent._simulated = false;
	            L$$1.Editable.PathEditor.prototype.onDrawingMouseMove.call(this, e);
	        },

	        onDrag: function (e) {
	            L$$1.Editable.PathEditor.prototype.onDrag.call(this, e);
	            this.feature.dragging.updateLatLng(this._resizeLatLng);
	        }

	    });

	    // 🍂namespace Editable; 🍂class EditableMixin
	    // `EditableMixin` is included to `L.Polyline`, `L.Polygon`, `L.Rectangle`, `L.Circle`
	    // and `L.Marker`. It adds some methods to them.
	    // *When editing is enabled, the editor is accessible on the instance with the
	    // `editor` property.*
	    var EditableMixin = {

	        createEditor: function (map) {
	            map = map || this._map;
	            var tools = (this.options.editOptions || {}).editTools || map.editTools;
	            if (!tools) throw Error('Unable to detect Editable instance.');
	            var Klass = this.options.editorClass || this.getEditorClass(tools);
	            return new Klass(map, this, this.options.editOptions);
	        },

	        // 🍂method enableEdit(map?: L.Map): this.editor
	        // Enable editing, by creating an editor if not existing, and then calling `enable` on it.
	        enableEdit: function (map) {
	            if (!this.editor) this.createEditor(map);
	            this.editor.enable();
	            return this.editor;
	        },

	        // 🍂method editEnabled(): boolean
	        // Return true if current instance has an editor attached, and this editor is enabled.
	        editEnabled: function () {
	            return this.editor && this.editor.enabled();
	        },

	        // 🍂method disableEdit()
	        // Disable editing, also remove the editor property reference.
	        disableEdit: function () {
	            if (this.editor) {
	                this.editor.disable();
	                delete this.editor;
	            }
	        },

	        // 🍂method toggleEdit()
	        // Enable or disable editing, according to current status.
	        toggleEdit: function () {
	            if (this.editEnabled()) this.disableEdit();
	            else this.enableEdit();
	        },

	        _onEditableAdd: function () {
	            if (this.editor) this.enableEdit();
	        }

	    };

	    var PolylineMixin = {

	        getEditorClass: function (tools) {
	            return (tools && tools.options.polylineEditorClass) ? tools.options.polylineEditorClass : L$$1.Editable.PolylineEditor;
	        },

	        shapeAt: function (latlng, latlngs) {
	            // We can have those cases:
	            // - latlngs are just a flat array of latlngs, use this
	            // - latlngs is an array of arrays of latlngs, loop over
	            var shape = null;
	            latlngs = latlngs || this._latlngs;
	            if (!latlngs.length) return shape;
	            else if (isFlat(latlngs) && this.isInLatLngs(latlng, latlngs)) shape = latlngs;
	            else for (var i = 0; i < latlngs.length; i++) if (this.isInLatLngs(latlng, latlngs[i])) return latlngs[i];
	            return shape;
	        },

	        isInLatLngs: function (l, latlngs) {
	            if (!latlngs) return false;
	            var i, k, len, part = [], p,
	                w = this._clickTolerance();
	            this._projectLatlngs(latlngs, part, this._pxBounds);
	            part = part[0];
	            p = this._map.latLngToLayerPoint(l);

	            if (!this._pxBounds.contains(p)) { return false; }
	            for (i = 1, len = part.length, k = 0; i < len; k = i++) {

	                if (L$$1.LineUtil.pointToSegmentDistance(p, part[k], part[i]) <= w) {
	                    return true;
	                }
	            }
	            return false;
	        }

	    };

	    var PolygonMixin = {

	        getEditorClass: function (tools) {
	            return (tools && tools.options.polygonEditorClass) ? tools.options.polygonEditorClass : L$$1.Editable.PolygonEditor;
	        },

	        shapeAt: function (latlng, latlngs) {
	            // We can have those cases:
	            // - latlngs are just a flat array of latlngs, use this
	            // - latlngs is an array of arrays of latlngs, this is a simple polygon (maybe with holes), use the first
	            // - latlngs is an array of arrays of arrays, this is a multi, loop over
	            var shape = null;
	            latlngs = latlngs || this._latlngs;
	            if (!latlngs.length) return shape;
	            else if (isFlat(latlngs) && this.isInLatLngs(latlng, latlngs)) shape = latlngs;
	            else if (isFlat(latlngs[0]) && this.isInLatLngs(latlng, latlngs[0])) shape = latlngs;
	            else for (var i = 0; i < latlngs.length; i++) if (this.isInLatLngs(latlng, latlngs[i][0])) return latlngs[i];
	            return shape;
	        },

	        isInLatLngs: function (l, latlngs) {
	            var inside = false, l1, l2, j, k, len2;

	            for (j = 0, len2 = latlngs.length, k = len2 - 1; j < len2; k = j++) {
	                l1 = latlngs[j];
	                l2 = latlngs[k];

	                if (((l1.lat > l.lat) !== (l2.lat > l.lat)) &&
	                        (l.lng < (l2.lng - l1.lng) * (l.lat - l1.lat) / (l2.lat - l1.lat) + l1.lng)) {
	                    inside = !inside;
	                }
	            }

	            return inside;
	        },

	        parentShape: function (shape, latlngs) {
	            latlngs = latlngs || this._latlngs;
	            if (!latlngs) return;
	            var idx = L$$1.Util.indexOf(latlngs, shape);
	            if (idx !== -1) return latlngs;
	            for (var i = 0; i < latlngs.length; i++) {
	                idx = L$$1.Util.indexOf(latlngs[i], shape);
	                if (idx !== -1) return latlngs[i];
	            }
	        }

	    };


	    var MarkerMixin = {

	        getEditorClass: function (tools) {
	            return (tools && tools.options.markerEditorClass) ? tools.options.markerEditorClass : L$$1.Editable.MarkerEditor;
	        }

	    };

	    var RectangleMixin = {

	        getEditorClass: function (tools) {
	            return (tools && tools.options.rectangleEditorClass) ? tools.options.rectangleEditorClass : L$$1.Editable.RectangleEditor;
	        }

	    };

	    var CircleMixin = {

	        getEditorClass: function (tools) {
	            return (tools && tools.options.circleEditorClass) ? tools.options.circleEditorClass : L$$1.Editable.CircleEditor;
	        }

	    };

	    var keepEditable = function () {
	        // Make sure you can remove/readd an editable layer.
	        this.on('add', this._onEditableAdd);
	    };

	    var isFlat = L$$1.LineUtil.isFlat || L$$1.LineUtil._flat || L$$1.Polyline._flat;  // <=> 1.1 compat.


	    if (L$$1.Polyline) {
	        L$$1.Polyline.include(EditableMixin);
	        L$$1.Polyline.include(PolylineMixin);
	        L$$1.Polyline.addInitHook(keepEditable);
	    }
	    if (L$$1.Polygon) {
	        L$$1.Polygon.include(EditableMixin);
	        L$$1.Polygon.include(PolygonMixin);
	    }
	    if (L$$1.Marker) {
	        L$$1.Marker.include(EditableMixin);
	        L$$1.Marker.include(MarkerMixin);
	        L$$1.Marker.addInitHook(keepEditable);
	    }
	    if (L$$1.Rectangle) {
	        L$$1.Rectangle.include(EditableMixin);
	        L$$1.Rectangle.include(RectangleMixin);
	    }
	    if (L$$1.Circle) {
	        L$$1.Circle.include(EditableMixin);
	        L$$1.Circle.include(CircleMixin);
	    }

	    L$$1.LatLng.prototype.update = function (latlng) {
	        latlng = L$$1.latLng(latlng);
	        this.lat = latlng.lat;
	        this.lng = latlng.lng;
	    };

	}, window));

	function applyDefaultPlot (FieldMap) {
	  FieldMap.prototype.defaultPlot = function (row, col, plotWidth, plotLength) {
	    plotWidth = plotWidth || this.opts.defaultPlotWidth;
	    plotLength = plotLength || this.opts.defaultPlotWidth;
	    var o = turf.point(this.opts.defaultPos);
	    var tl = turf.destination(
	      turf.destination(
	        o,
	        plotWidth*col,
	        90,
	        {'units': 'kilometers'}
	      ),
	      plotLength*row,
	      180,
	      {'units': 'kilometers'}
	    );
	    var br = turf.destination(
	      turf.destination(
	        tl,
	        plotWidth,
	        90,
	        {'units': 'kilometers'}
	      ),
	      plotLength,
	      180,
	      {'units': 'kilometers'}
	    );
	    var tr = turf.point([tl.geometry.coordinates[0], br.geometry.coordinates[1]]);
	    var bl = turf.point([br.geometry.coordinates[0], tl.geometry.coordinates[1]]);
	    return turf.polygon([
	      [tl, tr, br, bl, tl].map(turf.getCoord)
	    ], {});
	  };
	}

	const NO_POLYGON_ERROR = "Please select the area that contain the plots";

	const DEFAULT_OPTS = {
	  brapi_auth: null,
	  brapi_pageSize: 1000,
	  brapi_levelName: 'plot',
	  defaultPos: [0, 0],
	  defaultZoom: 2,
	  normalZoom: 16,
	  plotWidth: 0,
	  plotLength: 0,
	  plotScaleFactor: 1,
	  style: {
	    weight: 1
	  },
	  useGeoJson: true,
	  tileLayer: {
	    url: 'http://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}?blankTile=false',
	    options: {
	      attribution: '&copy; <a href="http://www.esri.com/">Esri</a>, DigitalGlobe, GeoEye, i-cubed, USDA FSA, USGS, AEX, Getmapping, Aerogrid, IGN, IGP, swisstopo, and the GIS User Community',
	      maxZoom: 28,
	      maxNativeZoom: 19
	    }
	  }
	};

	class Fieldmap {
	  constructor(map_container, brapi_endpoint, opts = {}) {
	    this.map_container = d3.select(map_container).style("background-color", "#888");
	    this.brapi_endpoint = brapi_endpoint;

	    // Parse Options
	    this.opts = Object.assign(Object.create(DEFAULT_OPTS), opts);
	    this.map = L.map(this.map_container.node(), {editable: true}).setView(this.opts.defaultPos, 2);
	    this.map.on('preclick', ()=>{
	      if (this.editablePolygon) this.finishTranslate();
	      if (this.editablePlot) this.finishPlotEdition();
	    });

	    this.tilelayer = L.tileLayer.fallback(this.opts.tileLayer.url, this.opts.tileLayer.options).addTo(this.map);

	    L.EditControl = L.Control.extend({
	      options: {
	        position: 'topleft',
	        callback: null,
	        title: '',
	        html: ''
	      },
	      onAdd: function (map) {
	        var container = L.DomUtil.create('div', 'leaflet-control leaflet-bar'),
	          link = L.DomUtil.create('a', '', container);
	        link.href = '#';
	        link.title = this.options.title;
	        link.innerHTML = this.options.html;
	        L.DomEvent.on(link, 'click', L.DomEvent.stop)
	          .on(link, 'click', function () {
	            window.LAYER = this.options.callback.call(map.editTools);
	          }, this);
	        return container;
	      }
	    });

	    let self = this;
	      L.NewPolygonControl = L.EditControl.extend({
	        options: {
	          position: 'topleft',
	          callback: function () {
	            self.polygon = self.map.editTools.startPolygon();
	            return self.polygon;
	          },
	          title: 'Creates a new polygon',
	          html: String.fromCodePoint(0x25B1)
	        }
	      });
	      L.NewRectangleControl = L.EditControl.extend({
	        options: {
	          position: 'topleft',
	          callback: function () {
	            self.polygon = self.map.editTools.startRectangle();
	            return self.polygon;
	          },
	          title: 'Creates a new rectangle',
	          html: String.fromCodePoint(0x25AD)
	        }
	      });
	      L.NewClearControl = L.EditControl.extend({
	        options: {
	          position: 'topleft',
	          callback: function () {
	            self.map.editTools.featuresLayer.clearLayers();
	          },
	          title: 'Clears all polygons',
	          html: String.fromCodePoint(0x1F6AB)
	        }
	      });

	    // Add additional map controls if NOT view only
	    if ( !this.opts.viewOnly ) {
	      this.map.addControl(new L.Control.Search({
	        url: 'https://nominatim.openstreetmap.org/search?format=json&q={s}',
	        jsonpParam: 'json_callback',
	        propertyName: 'display_name',
	        propertyLoc: ['lat', 'lon'],
	        autoCollapse: true,
	        autoType: false,
	        minLength: 2,
	        marker: false,
	        zoom: this.opts.normalZoom
	      }));

	      this.polygonControl = new L.NewPolygonControl();
	      this.rectangleControl = new L.NewRectangleControl();
	      this.clearPolygonsControl = new L.NewClearControl();

	      this.map.addControl(this.polygonControl);
	      this.map.addControl(this.rectangleControl);
	      this.map.addControl(this.clearPolygonsControl);
			}

	    this.info = this.map_container.append("div")
	      .style("bottom","5px")
	      .style("left","5px")
	      .style("position","absolute")
	      .style("z-index",2000)
	      .style("pointer-events","none")
	      .style("background", "white")
	      .style("border-radius", "5px");

	    this.missing_plots = this.map_container.append("div")
	      .style("bottom","5px")
	      .style("right","5px")
	      .style("position","absolute")
	      .style("z-index", 2000)
	      .style("background", "#DC3545")
	      .style("color", "#fff")
	      .style("border-radius", "5px")
	      .style("padding", "10px")
	      .style("font-weight", "bold")
	      .style("display", "none");

	    this.loading = this.map_container.append("div")
	      .style("top", 0)
	      .style("left", 0)
	      .style("position","absolute")
	      .style("z-index", 500)
	      .style("width", "100%")
	      .style("background", "#FFC107")
	      .style("display", "none")
	      .html("<p style='margin: 10px; text-align: center; font-weight: bold'>Loading Plots...</p>");

	    this.onLoading = (loading) => {
	      this.loading.style("display", loading ? 'block' : 'none');
	    }
	  }

	  removeControls() {
	    this.map.removeControl(this.polygonControl);
	    this.map.removeControl(this.rectangleControl);
	    this.map.removeControl(this.clearPolygonsControl);
	  }

	  load(studyDbId) {
	    this.onLoading(true);
	    this.generatePlots(studyDbId);
	    return this.data.then(()=>{
	      this.drawPlots();
	      this.onLoading(false);
	      return true;
	    }).catch(resp=>{
	      console.log(resp);
	      this.onLoading(false);
	    });
	  }

	  drawPlots() {
	    if (this.plotsLayer) this.plotsLayer.remove();
	    this.plotsLayer = L.featureGroup(this.plots.features.map((plot)=>{
			const geometry = convertCoordstoNumbers(plot);

			if (geometry.geometry.type === "Polygon" || geometry.geometry.type === "MultiPolygon") {
				const scaled = turf.transformScale(geometry, this.opts.plotScaleFactor);
				return L.geoJSON(scaled, this.opts.style);
			} else if (geometry.geometry.type === "Point") {
				return L.geoJSON(geometry, {
					pointToLayer: (feature, latlng) => {
						return L.circleMarker(latlng, {
							radius: 6,
							color: '#ff0000',
							fillColor: '#ff0000',
							fillOpacity: 0.8
						});
					}
				});
			}
	    })).on('contextmenu', (e)=>{
	      if (this.editablePlot) {
	        this.finishPlotEdition();
	      }
	      this.enableEdition(e.sourceTarget);
	    }).on('click', (e)=>{
	      if ( !this.opts.viewOnly ) this.enableTransform(e.target);
	    }).on('mousemove', (e)=>{
	      let sourceTarget = e.sourceTarget;
	      let ou = this.plot_map[sourceTarget.feature.properties.observationUnitDbId];
	      get_oup_rel(ou).forEach((levels)=>{ 
	          if(levels.levelName == 'replicate'){ ou.replicate = levels.levelCode;}
	        else if(levels.levelName == 'block'){ ou.blockNumber = levels.levelCode;}
	        else if(levels.levelName == 'plot'){ ou.plotNumber = levels.levelCode;}});
	      this.info.html(`<div style="padding: 5px"><div>Germplasm: ${ou.germplasmName}</div>
       <div>Replicate: ${ou.replicate}</div>
       <div>    Block: ${ou.blockNumber}</div>
       <div>  Row,Col: ${ou._row},${ou._col}</div>
       <div>   Plot #: ${ou.plotNumber}</div></div>`);
	    }).on('mouseout', ()=>{
	      this.info.html("");
	    }).addTo(this.map);
	  }

	  enableEdition(plot) {
	    this.editablePlot = plot;
	    plot.enableEdit();
	  }

	  finishPlotEdition() {
	    this.editablePlot.disableEdit();
	    this.plots = turf.featureCollection(this.plots.features.map((plot)=>{
	      if (plot.properties.observationUnitDbId == this.editablePlot.feature.properties.observationUnitDbId) {
	        let geojson = this.editablePlot.toGeoJSON();
	        plot = turf.convex(geojson);
	        plot.properties = geojson.properties;
	      }
	      return plot;
	    }));
	    this.editablePlot = null;
	  }

	  enableTransform(plotGroup) {
	    this.plotsLayer.remove();
	    this.editablePolygon = L.polygon(Fieldmap.featureToL(turf.convex(plotGroup.toGeoJSON())),
	      Object.assign({transform:true,draggable:true}, this.opts.style))
	      .on('dragend', (e)=>{
	        let target = e.target;
	        let startPos = turf.center(this.plots);
	        let endPos = turf.center(target.toGeoJSON());
	        this.plots = turf.transformTranslate(this.plots,
	          turf.distance(startPos, endPos),
	          turf.bearing(startPos, endPos));
	        this.finishTranslate();
	      })
	      .on('scaleend', (e)=>{
	        let target = e.target;
	        let startPos = turf.center(this.plots);
	        let endPos = turf.center(target.toGeoJSON());
	        let startArea = turf.area(this.plots);
	        let endArea = turf.area(target.toGeoJSON());
	        let factor = Math.sqrt(endArea/startArea);
	        this.plots = turf.featureCollection(this.plots.features.map((plot)=>{
	          let startCoord = turf.getCoords(startPos);
	          let plotCoord = turf.getCoords(turf.center(plot));
	          let bearing = turf.bearing(startCoord,plotCoord);
	          let distance = turf.distance(startCoord,plotCoord);
	          // after resize, bearing to centroid of all plots is the same, but scaled by the resize factor
	          let plotEndCoord = turf.getCoords(turf.destination(turf.getCoords(endPos),distance*factor,bearing));
	          plot = turf.transformTranslate(plot,
	            turf.distance(plotCoord, plotEndCoord),
	            turf.bearing(plotCoord, plotEndCoord));
	          plot = turf.transformScale(plot, factor);
	          return plot
	        }));
	        this.finishTranslate();
	      })
	      .on('rotateend', (e)=>{
	        this.plots = turf.transformRotate(this.plots, turf.radiansToDegrees(e.rotation));
	        this.finishTranslate();
	      })
	      .addTo(this.map);
	      this.editablePolygon.transform.enable();
	      this.editablePolygon.dragging.enable();
	  }

	  finishTranslate() {
	    let polygon = this.editablePolygon;
	    polygon.transform.disable();
	    polygon.dragging.disable();
	    this.drawPlots();
	    setTimeout(()=>{
	      this.editablePolygon.remove();
	      this.editablePolygon = null;
	    });
	  }

	  /**
	   * Try to make the polygon vertical before calculating row and col,
	   * by rotating it in an angle formed between the center and one of
	   * the far ends.
	   */
	  level() {
	    let cellSide = Math.sqrt(turf.area(this.geoJson))/1000/10/2;
	    let grid = turf.pointGrid(turf.bbox(this.geoJson), cellSide, {mask: this.geoJson});
	    let center = turf.getCoord(turf.centerOfMass(this.geoJson));
	    let distances = grid.features.map(f=>turf.distance(center, turf.getCoord(f))).sort();
	    let q3 = d3.quantile(distances, 0.75);
	    let clusters = turf.clustersKmeans(turf.featureCollection(grid.features.filter((f)=>{
	      return turf.distance(center,turf.getCoord(f)) > q3;
	    })), {numberOfClusters: 2});
	    let clusterCenters = [];
	    turf.clusterEach(clusters, 'cluster', (cluster)=>{
	      clusterCenters.push(turf.getCoord(turf.center(cluster)));
	    });
	    let bearing = turf.bearing(center, this.northernmost(clusterCenters[0], clusterCenters[1]));
	    this.rotation = 90-( (Math.round(Math.abs(bearing)) == 0 || Math.round(Math.abs(bearing)) == 90) ? 90:bearing);
	    this.geoJson = turf.transformRotate(this.geoJson, this.rotation);
	  }

	  northernmost() {
	    return [].slice.call(arguments).sort((a,b)=>b[1] - a[1])[0];
	  }

	  generatePlots(studyDbId) {
	    return this.load_ObsUnits(studyDbId)
	      .then((data)=>{
	        this.plots = turf.featureCollection(data.plots.map(p=>{
	          return Object.assign(p._geoJSON, {properties: {observationUnitDbId: p.observationUnitDbId}});
	        }));
	        if (!data.plots_shaped) {
	          // rotate to original position
	          this.plots = turf.transformRotate(this.plots, -this.rotation);
	        }
	        this.fitBounds(this.plots);
	      });
	  }

	  load_ObsUnits(studyDbId){
	    this.new_data = true;
	    this.data_parsed = 0;
	    this.data_total = 0;
	    if(this.data && this.data_parsed!=this.data_total){
	      this.data.reject("New Load Started");
	    }
	    var rej;
	    var rawdata = new Promise((resolve,reject)=>{
	      rej = reject;
	      const brapi = BrAPI(this.brapi_endpoint, "2.0", this.opts.brapi_auth);
	      var results = {'plots':[]};
	      brapi.search_observationunits({
	        "studyDbIds":[studyDbId],
	        'pageSize':this.opts.brapi_pageSize,
	        'observationLevels' : [{ "levelName" : this.opts.brapi_levelName }]
	      })
	        .each(ou=>{
	          ou.X = parseFloat(ou.X);
	          ou.Y = parseFloat(ou.Y);
	          if(ou.observationUnitPosition.observationLevel.levelName.toUpperCase() === "PLOT") results.plots.push(ou);
	          this.data_parsed+=1;
	          this.data_total = ou.__response.metadata.pagination.totalCount;
	        })
	        .all(()=>{
	          // ensure unique
	          this.plot_map = {};
	          results.plots = results.plots.reduce((acc,plot)=>{
	            if(!this.plot_map[plot.observationUnitDbId]){
	              this.plot_map[plot.observationUnitDbId] = plot;
	              acc.push(plot);
	            }
	            return acc;
	          },[]);

	          // sort
	          results.plots.sort(function(a,b){
	            if(a.plotNumber!=b.plotNumber){
	              return parseFloat(a.plotNumber)>parseFloat(b.plotNumber)?1:-1
	            }
	            return 1;
	          });

	          if(results.plots.length>0){
	            results.blocks = d3.nest().key(plot=>get_oup(plot).blockNumber).entries(results.plots);
	            results.reps = d3.nest().key(plot=>get_oup(plot).replicate).entries(results.plots);
	          }

	          clearInterval(this.while_downloading);
	          resolve(results);
	        });
	    });
	    this.data = rawdata.then((d)=>this.shape(d));
	    this.data.reject = rej;
	    this.while_downloading = setInterval(()=>{
	      var status = this.data_parsed+"/"+this.data_total;
	      console.log(status);
	    },500);
	    rawdata.catch(e=>{
	      clearInterval(this.while_downloading);
	      console.log(e);
	    });
	    return this.data;
	  }

	  shape(data){
	    data.shape = {};
	    // Determine what information is available for each obsUnit
	    data.plots.forEach((ou)=>{
	      const oup = get_oup(ou);
	      ou._X = ou.X || oup.positionCoordinateX;
	      ou._Y = ou.Y || oup.positionCoordinateY;
	      try {
	        ou._geoJSON = (this.opts.useGeoJson && oup.geoCoordinates)
	                      || null;
	      } catch (e) {}
	      ou._type = "";
	      if (!isNaN(ou._X) && !isNaN(ou._Y)){
	        if(oup.positionCoordinateXType
	          && oup.positionCoordinateYType){
	          if(oup.positionCoordinateXType=="GRID_ROW" && oup.positionCoordinateYType=="GRID_COL"
	            || oup.positionCoordinateXType=="GRID_COL" && oup.positionCoordinateYType=="GRID_ROW"){
	            ou._row = oup.positionCoordinateYType=="GRID_ROW" ? parseInt(ou._Y) : parseInt(ou._X);
	            ou._col = oup.positionCoordinateXType=="GRID_COL" ? parseInt(ou._X) : parseInt(ou._Y);
	          }
	          if(oup.positionCoordinateXType=="LONGITUDE" && oup.positionCoordinateYType=="LATITUDE"){
	            if(!ou._geoJSON) ou._geoJSON = turf.point([ou._X,ou._Y]);
	          }
	        }
	        else {
	          if(ou._X==Math.floor(ou._X) && ou._Y==Math.floor(ou._Y)){
	            ou._row = parseInt(ou._Y);
	            ou._col = parseInt(ou._X);
	          }
	          else {
	            try {
	              if(!ou._geoJSON) ou._geoJSON = turf.point([ou._X,ou._Y]);
	            } catch (e) {}
	          }
	        }
	      }
	      if(ou._geoJSON){
	        try {
	          ou._type = turf.getType(ou._geoJSON);
	        }
	        catch (err) {
	          ou._type = "invalid";
	        }
	      }
	      else {
	        ou._type = "missing";
	      }
	    });

	    // Separate out plots with invalid / missing geojson
	    if ( this.opts.viewOnly ) {
	      const plots_invalid = data.plots.filter((e) => e._type === 'invalid' || e._type === 'missing');
	      const plots_valid = data.plots.filter((e) => e._type !== 'invalid' && e._type !== 'missing');
	      if ( plots_valid.length === 0 ) {
	        let html = "This trial does not have any plots with geo coordinates assigned."
	        this.missing_plots.style("display", "block");
	        this.missing_plots.html(html);
	        throw NO_POLYGON_ERROR;
	      }
	      else if ( plots_invalid.length > 0 ) {
	        let html = "Plots with no geo coordinates:";
	        html += "<ul style='padding-left: 25px; margin-bottom: 0'>";
	        plots_invalid.forEach((p) => html += `<li>${p.observationUnitName}</li>`);
	        html += "</ul>";
	        this.missing_plots.style("display", "block");
	        this.missing_plots.html(html);
	      }
	      data.plots = plots_valid;
	    }

	    // Generate a reasonable plot layout if there is missing row/col data
	    if( data.plots.some(plot=>isNaN(plot._row)||isNaN(plot._col)) ){
	      var lyt_width = this.layout_width(
	        Math.round(d3.median(data.blocks,block=>block.values.length)),
	        data.plots.length
	      );
	      data.plots.forEach((plot,pos)=>{
	        let row = Math.floor(pos/lyt_width);
	        let col = (pos%lyt_width);
	        if (row%2==1) col = (lyt_width-1)-col;
	        plot._col = col;
	        plot._row = row;
	      });
	    }

	    // Shape Plots
	    data.plots_shaped = false;
	    if(data.plots.every(plot=>(plot._type=="Polygon"))){
	      // Plot shapes already exist!

	      data.plots_shaped = this.opts.useGeoJson;
	    }
	    else if(data.plots.every(plot=>(plot._type=="Point"||plot._type=="Polygon"))){
	      // Create plot shapes using centroid Voronoi
			
			var centroids = turf.featureCollection(data.plots.map((plot, pos) => {
				return turf.centroid(plot._geoJSON)
			}));

			if (centroids.features.length === 1) {
				//console.log("one point using buffer");
				const buffered = turf.buffer(centroids.features[0], 100, { units: 'centimeters' });
				data.plots[0]._geoJSON = buffered;
				data.plots_shaped = this.opts.useGeoJson;
			} else {
				var scale_factor = 50; //prevents rounding errors
				var scale_origin = turf.centroid(centroids);
				centroids = turf.transformScale(centroids,scale_factor,{origin:scale_origin});
				var bbox = turf.envelope(centroids);
				var area = turf.area(bbox);
				var offset = -Math.sqrt(area/data.plots.length)/1000/2;
				
				var convexHull = turf.convex(centroids, {units: 'kilometers'});
				if (convexHull) {
					var hull = turf.polygonToLine(convexHull);
					var crop = turf.lineToPolygon(turf.lineOffset(hull, offset, {units: 'kilometers'}));
					var voronoiBox = turf.lineToPolygon(turf.polygonToLine(turf.envelope(crop)));

					var cells = turf.voronoi(centroids,{bbox:turf.bbox(voronoiBox)});
					var cells_cropped = turf.featureCollection(cells.features.map(cell=>turf.intersect(cell,crop)));
					cells_cropped = turf.transformScale(cells_cropped,1/scale_factor,{origin:scale_origin});
					data.plots.forEach((plot,i)=>{
						plot._geoJSON = cells_cropped.features[i];
					});
					data.plots_shaped = this.opts.useGeoJson;
				} else {
					console.warn("Convex hull could not be computed, invalid points");
				}
			}
	      
	    }

	    let plot_XY_groups = {};
	    // group by plots with the same X/Y
	    data.plots.forEach(plot=>{
	      plot_XY_groups[plot._col] = plot_XY_groups[plot._col] || {};
	      plot_XY_groups[plot._col][plot._row] = plot_XY_groups[plot._col][plot._row] || {};
	      plot_XY_groups[plot._col][plot._row]=[plot];
	    });

	    if(!data.plots_shaped){
	      if (!this.polygon || !turf.area(this.polygon.toGeoJSON())) {
	        throw NO_POLYGON_ERROR;
	      }
	      this.geoJson = this.polygon.toGeoJSON();
	      this.polygon.remove();
	      this.level();
	      const bbox = turf.bbox(this.geoJson);
	      this.opts.defaultPos = [bbox[0], bbox[3]];
	      let plotLength = this.opts.plotLength/1000,
	        plotWidth = this.opts.plotWidth/1000;
	      const cols = Object.keys(plot_XY_groups).length,
	        rows =  Object.values(plot_XY_groups).reduce((acc, col)=>{
	          Object.keys(col).forEach((row, i)=>{
	            if (!row) return;
	            acc[i] = acc[i]+1 || 1;
	          });
	          return acc;
	        }, []).filter(x=>x).length;
	      plotLength = plotLength || turf.length(turf.lineString([[bbox[0], bbox[1]], [bbox[0], bbox[3]]]))/rows;
	      plotWidth = plotWidth || turf.length(turf.lineString([[bbox[0], bbox[1]], [bbox[2], bbox[1]]]))/cols;
	      // Use default plot shapes/positions based on X/Y positions
	      for (let X in plot_XY_groups) {
	        if (plot_XY_groups.hasOwnProperty(X)) {
	          for (let Y in plot_XY_groups[X]) {
	            if (plot_XY_groups[X].hasOwnProperty(Y)) {
	              X = parseInt(X);
	              Y = parseInt(Y);
	              let polygon = this.defaultPlot(Y-1, X-1, plotWidth, plotLength);
	              // if for some reason plots have the same x/y, split that x/y region
	              plot_XY_groups[X][Y].forEach((plot, i)=>{
	                plot._geoJSON = this.splitPlot(polygon, plot_XY_groups[X][Y].length, i);
	              });
	            }
	          }
	        }
	      }
	    }

	    return data;
	  }

	  fitBounds(feature) {
	    let bbox = turf.bbox(feature);
	    this.map.fitBounds([[bbox[1], bbox[0]], [bbox[3], bbox[2]]]);
	  }

	  layout_width(median_block_length,number_of_plots){
	    let bllen = median_block_length;
	    let squarelen = Math.round(Math.sqrt(number_of_plots));
	    let lyt_width;
	    if(squarelen==bllen){
	      lyt_width = squarelen;
	    }
	    else if (squarelen>bllen) {
	      lyt_width = Math.round(squarelen/bllen)*bllen;
	    }
	    else {
	      let closest_up = (bllen%squarelen)/Math.floor(bllen/squarelen);
	      let closest_down = (squarelen-bllen%squarelen)/Math.ceil(bllen/squarelen);
	      lyt_width = Math.round(
	        closest_up<=closest_down?
	          squarelen+closest_up:
	          squarelen-closest_down
	      );
	    }
	    return lyt_width;
	  }

	  splitPlot(polygon,partitions,index){
	    this.splitPlot_memo = this.splitPlot_memo || {};
	    let memo_key = `(${partitions})${polygon.geometry.coordinates.join(",")}`;
	    if(this.splitPlot_memo[memo_key]) return this.splitPlot_memo[memo_key][index];
	    if(!partitions||partitions<2) return (this.splitPlot_memo[memo_key] = [polygon])[index];

	    let scale_factor = 50; //prevents rounding errors
	    let scale_origin = turf.getCoord(turf.centroid(polygon));
	    polygon = turf.transformScale(polygon, scale_factor, {'origin':scale_origin});

	    let row_width = Math.ceil(Math.sqrt(partitions));
	    let row_counts = [];
	    for (var i = 0; i < Math.floor(partitions/row_width); i++) {
	      row_counts[i] = row_width;
	    }
	    if(partitions%row_width) row_counts[row_counts.length] = partitions%row_width;

	    let polygonbbox = turf.bbox(polygon);
	    polygonbbox[0]-=0.00001; polygonbbox[1]-=0.00001; polygonbbox[2]+=0.00001; polygonbbox[3]+=0.00001;
	    let w = Math.sqrt(turf.area(polygon))/1000;
	    let area = 50+100*partitions;
	    let grid_dist = w/Math.sqrt(area);
	    let grid = turf.pointGrid(polygonbbox,grid_dist,{'mask':polygon});
	    let points = grid.features;

	    let points_per_part = Math.floor(points.length/partitions);

	    let row_point_counts = row_counts.map(rc=>rc*points_per_part);

	    points = points.sort((b,a)=>d3.ascending(turf.getCoord(a)[1],turf.getCoord(b)[1]));

	    let t = 0;
	    let rows = [];
	    row_point_counts.forEach((rpc,i)=>{
	      rows[i] = [];
	      while (rows[i].length<rpc && t<points.length){
	        rows[i].push(points[t++]);
	      }
	    });

	    let collecs = [];
	    rows.forEach((row,ri)=>{
	      row = row.sort((a,b)=>d3.ascending(turf.getCoord(a)[0],turf.getCoord(b)[0]));
	      let p = 0;
	      let c0 = collecs.length;
	      for (var ci = c0; ci < c0+row_counts[ri]; ci++) {
	        collecs[ci] = [];
	        while (collecs[ci].length<points_per_part && p<row.length){
	          collecs[ci].push(row[p++]);
	        }
	      }
	    });
	    let centroids = turf.featureCollection(collecs.map(c=>turf.centroid(turf.featureCollection(c))));
	    var voronoi = turf.voronoi(
	      centroids,
	      {'bbox':polygonbbox}
	    );
	    this.splitPlot_memo[memo_key] = voronoi.features.map(vc=>{
	      var mask = turf.mask(vc,turf.bboxPolygon(polygonbbox));
	      var c = turf.difference(polygon,mask);
	      return turf.transformScale(c, 1/scale_factor, {'origin':scale_origin})
	    });
	    return this.splitPlot_memo[memo_key][index];
	  }

	  static featureToL(feature) {
	    return turf.getCoords(turf.flip(feature));
	  }

	  setLocation(studyDbId) {
	    return new Promise((resolve, reject) => {
	      this.brapi = BrAPI(this.brapi_endpoint, "2.0", this.opts.brapi_auth);
	      this.brapi.studies_detail({studyDbId: studyDbId}).map((study) => {
	        if (!study) {
	          reject();
	          return;
	        }
	        if (study.location && study.location.latitude && study.location.longitude) {
	          // XXX some clients use the brapi v1 format
	          this.map.setView([
	            study.location.latitude,
	            study.location.longitude
	          ], this.opts.normalZoom);
	          resolve();
	        } else if (study.locationDbId) {
	          this.brapi.locations_detail({locationDbId: study.locationDbId}).map((location) => {
	            if (!location || !location.coordinates) {
	              reject();
	              return;
	            }
	            this.map.setView(Fieldmap.featureToL(location.coordinates), this.opts.normalZoom);
	            resolve();
	          });
	        } else {
	          reject();
	        }
	      });
	    });
	  }

	  debug(feature) {
	    L.geoJSON(feature, {color: 'red'}).addTo(this.map);
	    return feature;
	  }

	  update() {
	    if (!this.plots) {
	      return Promise.reject('There are no plots loaded');
	    }
	    let brapi = BrAPI(this.brapi_endpoint, "2.0", this.opts.brapi_auth);

			let params = {};
			this.plots.features.forEach((plot)=>{
					params[plot.properties.observationUnitDbId] = {
					observationUnitPosition: {geoCoordinates: plot, observationLevel:{levelName: this.opts.brapi_levelName }}
					};
			});

			return new Promise((resolve, reject)=> {
				if ( Object.keys(params).length > 0 ) {
					brapi.simple_brapi_call({
						'defaultMethod': 'put',
						'urlTemplate': '/observationunits?pageSize={pageSize}',
						'params': { pageSize: Object.keys(params).length+1, ...params },
						'behavior': 'map'
					}).all(() => {
						return resolve("Plots updated!");
					});
				} else {
					return reject('There are no plots loaded');
				}
			});
	  }
	}

	function get_oup(ou) {
	  return ou.observationUnitPosition || {};
	}

	function get_oup_rel(ou) {
	  return (ou.observationUnitPosition || {}).observationLevelRelationships || {};
	}

	function convertCoordstoNumbers(geo_object) {
		if (geo_object.geometry.type === "Polygon") {
			geo_object.geometry.coordinates = geo_object.geometry.coordinates.map(ring =>
				ring.map(coord => coord.map(Number))
			);
		} else if (geo_object.geometry.type === "Point") {
			geo_object.geometry.coordinates = geo_object.geometry.coordinates.map(Number);
		}
		return geo_object;
	}

	applyDefaultPlot(Fieldmap);

	return Fieldmap;

})));
