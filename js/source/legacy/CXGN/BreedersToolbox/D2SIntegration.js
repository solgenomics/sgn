/**
 * JS Class for handling the BB / D2S Integration
 * 
 * Example Usage:
 * var D2S = await new D2SAPI().init();                 // to use the user's API Key stored in the BB Database
 * var D2S = await new D2SAPI().init("api_key_value");  // to use a specific API Key
 * 
 * To Store an API Key for the current user:
 * await D2S.saveApiKey("new_api_key");
 * 
 * To check for linked D2S Projects:
 * const links = await D2S.getBBConnections(trial_id);  // will return the project ids, names, and urls for linked projects
 */
class D2SAPI {
    constructor(host) {
        this.api_host = host;
        this.api_prefix = "/api/v1";
        this.api_key;
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
            links.forEach((link) => {
                const project_id = link.project_id;

                // TODO: Get project details (such as project name)

                rtn.push({
                    id: project_id,
                    url: `${this.api_host}/projects/${project_id}`,
                    name: 'Project Name'
                });
            });
        }
        return rtn;
    }

    async getProject(project_id) {

    }


    async request(method, path, body) {
        return new Promise(async (resolve, reject) => {
            if ( !this.hasApiKey() ) return reject("D2S API Key not set!");
            let url = [this.api_host, this.api_prefix, path].join('');
            console.log(`[${method}] ${url}`);
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