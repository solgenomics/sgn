/**
 * Declarative search state utility.
 * 
 * This module provides a highly reusable, framework-agnostic controller class
 * to handle serializing and deserializing search page form elements into the 
 * URL query parameters. This eliminates repetitive parameter parsing and 
 * auto-trigger logic across all search pages.
 */

/**
 * Configuration interface representing a single form element mapping.
 */
export interface ElementConfig {
    // jQuery selector targeting the DOM element
    selector: string;
    // Defines how the state should be interpreted from/to the DOM
    type?: 'text' | 'checkbox' | 'select' | 'multi-checkbox' | 'json';
    // When true, the deserializer will wait/poll until an option with the target value exists in the select element before setting it.
    waitForOptions?: boolean;
    // When true, the deserializer will wait/poll until the element selector exists in the DOM.
    waitForElement?: boolean;
    // Timeout in milliseconds for waitForOptions polling (defaults to 3000)
    timeout?: number;
    // Custom function to retrieve the value. 
    // Uses 'unknown' to safely accommodate variable structures (e.g., arrays, maps, nested objects).
    getValue?: () => unknown;
    // Custom function to set the value.
    // Uses 'unknown' to accommodate heterogeneous inputs. Can return a Promise to allow async cascading lookups.
    setValue?: (val: unknown) => void | Promise<void>;
}

/**
 * Suffix configuration rules for identifying and expanding collapsible parent panels
 * when child fields are restored with active state parameters on page load.
 * 
 * SGN templates traditionally wrap advanced/collapsible form sections inside `info_section.mas`
 * markup, which generates container IDs and trigger buttons with standardized suffix pairings.
 */
export interface ParentExpansionRules {
    /**
     * Suffix identifying the collapsible parent content container element in the DOM tree.
     * Defaults to `_content` (e.g., matching `#advanced_search_panel_content`).
     */
    contentSuffix?: string;
    /**
     * Suffix appended to the parent prefix to identify the toggle button to trigger for expansion.
     * Defaults to `_onswitch` (e.g., matching `#advanced_search_panel_onswitch`).
     */
    toggleSuffix?: string;
}

/**
 * Configuration parameters representing the overall layout state.
 */
export interface SearchStateConfig {
    // Declarative map of parameter keys to element configurations
    elements: Record<string, ElementConfig>;
    // Selector or list of selectors targeting search submission buttons
    submitButtonSelector: string | string[];
    // Selector, list of selectors, or a mapping of specific reset selectors to targeted element keys to reset
    resetButtonSelector?: string | string[] | Record<string, string[]>;
    // Callback function to execute when a search is triggered
    onSearch?: () => void;
    // Callback function to execute when a reset is triggered
    onReset?: (resetKeys?: string[]) => void;
    // Callback function to execute when managed query parameters are restored on load
    onRestore?: (restoredKeys: string[]) => void;
    // Suffix rules for collapsing/expanding parent elements
    parentExpansionRules?: ParentExpansionRules;
}

/**
 * Reusable helper to poll a specific DOM/data condition.
 */
function pollCondition(conditionFn: () => boolean, timeout = 3000): Promise<boolean> {
    return new Promise((resolve) => {
        let finished = false;
        const interval = setInterval(() => {
            if (!finished && conditionFn()) {
                finished = true;
                clearInterval(interval);
                resolve(true);
            }
        }, 50);
        setTimeout(() => {
            clearInterval(interval);
            if (finished) return;
            finished = true;
            resolve(false);
        }, timeout);
    });
}

/**
 * Coerces a single value or an array of values into a guaranteed array of values.
 */
function ensureArray<T>(val: T | T[]): T[] {
    return Array.isArray(val) ? val : [val];
}

export class SearchStateManager {
    private readonly config: SearchStateConfig;
    private readonly submitSelectors: string[];
    private readonly resetSelectors?: string[] | Record<string, string[]>;

    constructor(config: SearchStateConfig) {
        this.config = config;
        this.submitSelectors = ensureArray(config.submitButtonSelector);
        if (config.resetButtonSelector) {
            if (typeof config.resetButtonSelector === 'object' && !Array.isArray(config.resetButtonSelector)) {
                this.resetSelectors = config.resetButtonSelector;
            } else {
                this.resetSelectors = ensureArray(config.resetButtonSelector);
            }
        }
    }

    /**
     * Serializes current DOM states and custom components into a key-value map.
     * Iterates through the element registry to gather text, selections, checkboxes,
     * and complex JSON states.
     */
    public serialize(): Record<string, string> {
        const params: Record<string, string> = {};

        for (const [key, element] of Object.entries(this.config.elements)) {
            // Process custom serialize overrides if defined (e.g., JSON structures)
            if (element.getValue) {
                const val = element.getValue();
                if (val !== undefined && val !== null && val !== '') {
                    params[key] = typeof val === 'object' ? JSON.stringify(val) : String(val);
                }
                continue;
            }

            // Resolve standard DOM states via jQuery selectors
            const $el = jQuery(element.selector);
            if (!$el.length) {
                continue;
            }

            if (element.type === 'checkbox') {
                // Serializes boolean check states
                if ($el.is(':checked')) {
                    params[key] = 'true';
                }
            } else if (element.type === 'multi-checkbox') {
                // Serializes grouped checkbox arrays as comma-separated lists
                const checkedVals: string[] = [];
                $el.filter(':checked').each(function() {
                    const val = jQuery(this).val();
                    if (val) {
                        checkedVals.push(String(val));
                    }
                });
                if (checkedVals.length > 0) {
                    params[key] = checkedVals.join(',');
                }
            } else {
                // Serializes fallback text inputs, selects, and textareas
                const val = $el.val();
                if (val !== undefined && val !== null && val !== '') {
                    params[key] = String(val);
                }
            }
        }
        return params;
    }

    /**
     * Parses the current URL query string and populates mapped elements.
     * Iterates through configurations, identifies matched URL keys, updates fields,
     * 
     * Supports sequential async lookups for dependent/cascading fields.
     * and handles programmatically expanding collapsible advanced option panels.
     */
    public async deserialize(): Promise<void> {
        const urlParams = new URLSearchParams(window.location.search);

        for (const [key, element] of Object.entries(this.config.elements)) {
            const val = urlParams.get(key);
            if (val === null) {
                continue;
            }

            // Wait for element to exist in the DOM if requested
            if (element.waitForElement && element.selector) {
                const selector = element.selector;
                await pollCondition(
                    () => jQuery(selector).length > 0,
                    element.timeout || 3000
                );
            }

            const $el = element.selector ? jQuery(element.selector) : null;

            if (element.setValue) {
                // Process custom deserialize overrides (e.g. nested JSON configs)
                if (element.type === 'json') {
                    try {
                        const parsed = JSON.parse(val);
                        const result = element.setValue(parsed);
                        if (result instanceof Promise) {
                            await result;
                        }
                    } catch (e) {
                        console.error(`Error parsing JSON parameter for ${key}`, e);
                    }
                } else {
                    const result = element.setValue(val);
                    if (result instanceof Promise) {
                        await result;
                    }
                }
            } else if ($el && $el.length) {
                // Set values on standard DOM fields
                if (element.type === 'checkbox') {
                    $el.prop('checked', val === 'true');
                } else if (element.type === 'multi-checkbox') {
                    const items = val.split(',');
                    $el.each(function () {
                        const currentVal = jQuery(this).val();
                        if (currentVal && items.includes(String(currentVal))) {
                            jQuery(this).prop('checked', true);
                        } else {
                            jQuery(this).prop('checked', false);
                        }
                    });
                } else {
                    if (element.waitForOptions) {
                        const selector = element.selector;
                        await pollCondition(() => {
                            const $currentEl = jQuery(selector);
                            return $currentEl.length > 0 && $currentEl.find(`option[value="${val}"]`).length > 0;
                        }, element.timeout || 3000);
                    }
                    
                    $el.val(val);
                }
                $el.trigger('change');
            }

            // Auto-expand any collapsed parent panels for this element
            if ($el && $el.length) {
                const contentSuffix = this.config.parentExpansionRules?.contentSuffix ?? '_content';
                const toggleSuffix = this.config.parentExpansionRules?.toggleSuffix ?? '_onswitch';
                const parentSelector = `[id$="${contentSuffix}"]`;

                const parents = $el.parents(parentSelector);
                if (parents.length) {
                    const parentElements = parents.toArray().reverse();
                    for (const parent of parentElements) {
                        const $parent = jQuery(parent);

                        const id = $parent.attr('id');
                        if (id && id.endsWith(contentSuffix)) {
                            const prefix = id.slice(0, -contentSuffix.length);
                            const $toggle = jQuery('#' + prefix + toggleSuffix);
                            const isCollapsed = parent.style.display === 'none' || (
                                $parent.hasClass('collapse') &&
                                !$parent.hasClass('in') &&
                                !$parent.hasClass('show')
                            );

                            if (isCollapsed && $toggle.length) {
                                $toggle.trigger('click');
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * Serializes current input states and commits them into the URL query parameters
     * without triggering a disruptive page reload.
     */
    public updateUrl(): void {
        const urlParams = new URLSearchParams(window.location.search);

        // Clear out only the managed search parameters
        for (const key of Object.keys(this.config.elements)) {
            urlParams.delete(key);
        }

        // Merge in the newly serialized search state
        const searchParams = this.serialize();
        for (const [key, value] of Object.entries(searchParams)) {
            urlParams.set(key, value);
        }

        if (typeof urlParams.sort === 'function') {
            urlParams.sort();
        }
        const qString = urlParams.toString();
        const nextUrl = qString ? '?' + qString : window.location.pathname;

        const currentUrlParams = new URLSearchParams(window.location.search);
        if (typeof currentUrlParams.sort === 'function') {
            currentUrlParams.sort();
        }
        const currentUrl = currentUrlParams.toString() ? '?' + currentUrlParams.toString() : window.location.pathname;

        // Only add history if the URL has changed
        if (currentUrl !== nextUrl) {
            window.history.pushState(null, '', nextUrl);
        }
    }

    /**
     * Resets form fields, clears query parameters in the URL, and triggers callback updates.
     * If a list of keys is provided, only those targeted elements and URL parameters are reset.
     */
    public reset(keys?: string[]): void {
        const targetKeys = keys || Object.keys(this.config.elements);

        for (const key of targetKeys) {
            const element = this.config.elements[key];
            if (!element) continue;

            if (element.setValue) {
                if (element.type === 'json') {
                    element.setValue({});
                } else {
                    element.setValue('');
                }
                continue;
            }

            const $el = element.selector ? jQuery(element.selector) : null;
            if (!$el || !$el.length) {
                continue;
            }

            if (element.type === 'checkbox' || element.type === 'multi-checkbox') {
                $el.prop('checked', false).trigger('change');
            } else if ($el.is('select')) {
                $el.prop('selectedIndex', 0).trigger('change');
            } else {
                $el.val('').trigger('change');
            }
        }

        const urlParams = new URLSearchParams(window.location.search);

        // Purge only managed search parameters, leaving unmanaged keys intact
        for (const key of targetKeys) {
            urlParams.delete(key);
        }

        const qString = urlParams.toString();
        const nextUrl = qString ? '?' + qString : window.location.pathname;

        const currentUrlParams = new URLSearchParams(window.location.search);

        if (currentUrlParams.toString() !== qString) {
            window.history.pushState(null, '', nextUrl);
        }

        if (this.config.onReset) {
            this.config.onReset(keys);
        }
    }

    /**
     * Mounts listeners, triggers state restorations, and executes auto-triggers.
     *
     * @returns A promise that resolves to an array of keys that were restored from the URL.
     */
    public async init(): Promise<string[]> {
        // De-serialize and restore state from existing URL query parameters on load
        await this.deserialize();

        // Intercept the search execution event to update query params and trigger callbacks
        this.submitSelectors.forEach(selector => {
            jQuery(selector).on('click', () => {
                this.updateUrl();
                if (this.config.onSearch) {
                    this.config.onSearch();
                }
            });
        });

        // Intercept the reset execution event to clear states
        if (this.resetSelectors) {
            if (!Array.isArray(this.resetSelectors)) {
                // Structured selector-to-keys mapping: Record<string, string[]>
                for (const [selector, targetKeys] of Object.entries(this.resetSelectors)) {
                    jQuery(selector).on('click', (e) => {
                        e.preventDefault();
                        this.reset(targetKeys);
                    });
                }
            } else {
                // Simple selector or selector array: string[]
                this.resetSelectors.forEach(selector => {
                    jQuery(selector).on('click', (e) => {
                        e.preventDefault();
                        this.reset();
                    });
                });
            }
        }

        // Auto-trigger search if managed query parameters were restored on load
        const urlParams = new URLSearchParams(window.location.search);
        const restoredKeys = Object.keys(this.config.elements)
            .filter(key => urlParams.has(key));

        if (restoredKeys.length > 0) {
            if (this.config.onRestore) {
                this.config.onRestore(restoredKeys);
            } else if (this.submitSelectors.length === 1) {
                // Fall back to triggering the single submit button only if there is no ambiguity
                jQuery(this.submitSelectors[0]).trigger('click');
            }
        }

        return restoredKeys;
    }
}

/**
 * Factory helper method to initialize the state manager
 * 
 * @example
 * var searchManager = window.jsMod['search_state'].create({
 *     submitButtonSelector: '#search_submit',
 *     resetButtonSelector: '#search_reset',
 *     elements: {
 *         any_name: { selector: '#any_name_input' },
 *         type: { selector: '#type_select' }
 *     },
 *     onSearch: function() {
 *         // Reload Datatable here
 *         _draw_results_table();
 *     }
 * });
 * 
 * // Init returns a promise resolving to the restored parameter keys
 * searchManager.init().then(function(restoredKeys) {
 *     // If no query parameters were restored on load, trigger a default "browse all" search
 *     if (restoredKeys.length === 0) {
 *         _draw_results_table();
 *     }
 * });
 */
export function create(config: SearchStateConfig): SearchStateManager {
    return new SearchStateManager(config);
}
