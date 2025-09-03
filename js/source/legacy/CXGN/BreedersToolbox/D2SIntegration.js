/**
 * JS Class for handling the BB / D2S Integration
 * 
 * Example Usage:
 * var D2S = await new D2SAPI({ host: "https://ps2.d2s.org", tileserver: "https://tileserver.com?url={url}"}).init();                 // to use the user's API Key stored in the BB Database
 * var D2S = await new D2SAPI({ host: "https://ps2.d2s.org", tileserver: "https://tileserver.com?url={url}"}).init("api_key_value");  // to use a specific API Key
 * 
 * To Store an API Key for the current user:
 * await D2S.saveApiKey("new_api_key");
 * 
 * To check for linked D2S Projects:
 * const links = await D2S.getBBConnections(trial_id);  // will return the project ids, names, and urls for linked projects
 * 
 * To get the geo coords for the plots in a D2S project:
 * const coords = await D2S.getCoords(project_id);      // will return an array of geoJSON objects, one for each plot
 * 
 * To get the available orthos for a project:
 * const orthos = await D2S.getOrthos(project_id);      // will return an array of objects with ortho metadata, including a URL for the configured tileserver
 */
class D2SAPI {
    constructor({ host, tileserver, base_url }) {
        this.enabled = !!host && host !== "";
        this.api_host = host;
        this.api_prefix = "/api/v1";
        this.api_key;
        this.base_url = base_url && base_url !== '' ? new URL(base_url).origin : location.origin;
        this.tileserver = tileserver;
    }

    // Initialize the D2S instance
    // Set the API Key with a provided value
    // or fetch the user's API Key stored in the database
    async init(d2s_api_key) {
        this.api_key = d2s_api_key || await this.getApiKey();
        return this;
    }

    // Check if there is an API Key Set
    hasApiKey() {
        return !!this.api_key && this.api_key !== "";
    }

    // Get API Key
    // if there is one already set for the instance, use that
    // otherwise check for one stored for the user in the database
    async getApiKey() {
        return new Promise((resolve, reject) => {

            // Return the set API Key, if it exists
            if ( this.hasApiKey() ) return resolve(this.api_key);

            // Otherwise fetch the user's stored api key from the database
            jQuery.ajax({
                url: "/ajax/user/preferences/d2s_api_key",
                success: (resp) => {
                    var stored_api_key = resp?.d2s_api_key;
                    this.api_key = stored_api_key;
                    resolve(stored_api_key);
                },
                error: () => {
                    reject("Could not fetch D2S API Key");
                }
            });

        });
    }

    // Save API Key
    // Save a new API Key in the database for the current user
    async saveApiKey(new_api_key) {
        return new Promise((resolve, reject) => {
            jQuery.ajax({
                method: 'POST',
                url: "/ajax/user/preferences",
                data: { "d2s_api_key": new_api_key },
                success: async (resp) => {
                    if ( resp && resp.d2s_api_key === new_api_key ) {
                        this.api_key = new_api_key;
                        resolve(new_api_key);
                    }
                    else {
                        reject("Your D2S API Key was NOT saved.  Please try again later.");
                    }
                },
                error: () => {
                    reject("There was an error saving your API Key.  Please try again later.");
                }
            });
        });
    }

    // Get BB Connections
    async getBBConnections(trial_id) {
        let rtn = [];
        const links = await this.request("GET", `/breedbase-connections/study/${trial_id}`);
        if ( links ) {
            for ( const link of links ) {
                const project_id = link.project_id;
                const base_url = new URL(link.base_url).origin;
                if ( base_url === this.base_url ) {
                    const project_details = await this.getProject(project_id);
                    rtn.push({
                        id: project_id,
                        url: `${this.api_host}/projects/${project_id}`,
                        name: project_details.title,
                        flights: project_details.flight_count || 0
                    });
                }
                else {
                    console.log(`Linked D2S project has a different base url: d2s=${base_url}, bb=${this.base_url}`);
                }
            };
        }
        return rtn;
    }

    // Get D2S Project Details
    async getProject(project_id) {
        return await this.request("GET", `/projects/${project_id}`);
    }

    // Get the Geo Coordinates for a project
    // Returns an array of geojson objects, one for each plot
    // This will add the .properties._parsed_plot, .properties._parsed_row, and .properties._parsed_col keys to each geojson object
    async getCoords(project_id) {
        const coords = [];

        // Get the project's vector layers
        const vector_layers = await this.request("GET", `/projects/${project_id}/vector_layers`);

        // Get the vector layer that has type of polygon
        let vector_id;
        if ( vector_layers && Array.isArray(vector_layers) ) {
            vector_layers.forEach((vl) => {
                if ( vl.geom_type === 'polygon' ) {
                    vector_id = vl.layer_id;
                }
            });
        }

        // If there is a polygon layer...
        if ( vector_id ) {

            // Download the vector layer as geo json
            const geo_json = await this.request("GET", `/projects/${project_id}/vector_layers/${vector_id}/download?format=json`);

            // Parse each feature in the vector layer
            if ( geo_json.features && Array.isArray(geo_json.features) ) {
                geo_json.features.forEach((f) => {

                    // Extract plot, row, and col numbers
                    for ( const prop of Object.keys(f.properties?.properties || {}) ) {
                        const value = f.properties.properties[prop];
                        if ( prop.toLowerCase().startsWith("plot") ) {
                            f.properties._parsed_plot = parseInt(value);
                        }
                        else if ( prop.toLowerCase().startsWith("row") ) {
                            f.properties._parsed_row = parseInt(value);
                        }
                        else if ( prop.toLowerCase().startsWith("col") ) {
                            f.properties._parsed_col = parseInt(value);
                        }
                    }

                    coords.push(f);
                });
            }

        }

        return coords;
    }

    // Get the Orthos for the specified project
    // Include a URL for the ortho that can be displayed using a tileserver
    async getOrthos(project_id) {
        if ( !this.tileserver || this.tileserver === '' ) throw "Ortho Tileserver is not configured!";
        const orthos = [];

        // Get all of the project's flights
        const flights = await this.request("GET", `/projects/${project_id}/flights`);

        // Parse each flight
        if ( flights ) {
            for ( const flight of flights ) {

                // Parse each flight's data products
                if ( flight.data_products ) {
                    for ( const dp of flight.data_products ) {

                        // Set additional params, depending on layer stats
                        let params = [];
                        const rasters = dp.stac_properties?.raster;
                        if ( rasters && rasters.length === 1 ) {
                            const min = rasters[0].stats?.minimum;
                            const max = rasters[0].stats?.maximum;
                            if ( min && max ) {
                                params.push(`rescale=${min},${max}`);
                                params.push('colormap_name=viridis');
                            }
                        }

                        // Add API Key to GeoTiff URL
                        // Add URL to tileserver layer
                        const url = dp.url + `?API_KEY=${await this.getApiKey()}`;
                        const layer = this.tileserver.replaceAll('{url}', `${url}&`).replaceAll('{params}', params.join('&'));

                        // Add data product info to list of orthos
                        orthos.push({
                            flight: flight.id,
                            sensor: flight.sensor,
                            platform: flight.platform,
                            data_product: dp.id,
                            data_type: dp.data_type,
                            date: flight.acquisition_date,
                            url: layer,
                            attribution: "Data2Science"
                        });

                    }
                }
            }
        }

        return orthos;
    }

    // Make a Generic D2S API Requeset
    async request(method, path, body) {
        return new Promise(async (resolve, reject) => {
            if ( !this.enabled ) return reject("D2S API Integration not enabled!");
            if ( !this.hasApiKey() ) return reject("D2S API Key not set!");
            let url = [this.api_host, this.api_prefix, path].join('');
            console.debug(`[D2S API] ${method} ${url}`);
            jQuery.ajax({
                method: method,
                url: url,
                headers: {
                    'X-API-KEY': await this.getApiKey()
                },
                data: body,
                success: async (resp = {}) => {
                    resolve(resp);
                },
                error: () => {
                    reject("Could not request data from D2S API. Please try again later.");
                }
            });
        });
    }
}