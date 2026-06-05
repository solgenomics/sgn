import test from 'tape';
import { create } from '../source/entries/search_state';

import jQuery from 'jquery';

// Expose jQuery to the global scope since search_state expects global jQuery / $
(globalThis as any).jQuery = jQuery;
(globalThis as any).$ = jQuery;

/**
 * Sets up a clean HTML form environment in JSDOM before each test.
 */
function setupDOM() {
    document.body.innerHTML = `
        <div id="test_form">
            <!-- Collapsible parent section simulation (standard info_section.mas structure) -->
            <div id="advanced_panel_onswitch" class="toggle-btn" style="cursor: pointer;">Toggle Advanced</div>
            <div id="advanced_panel_content" class="collapse" style="display: none;">
                <input type="text" id="test_name" value="" />
                <input type="checkbox" id="test_active" />
                
                <select id="test_dropdown">
                    <option value="">--Select--</option>
                    <option value="val1">Option 1</option>
                    <option value="val2">Option 2</option>
                </select>

                <input type="checkbox" name="test_multi" value="apple" />
                <input type="checkbox" name="test_multi" value="banana" />
                <input type="checkbox" name="test_multi" value="cherry" />
            </div>

            <button id="submit_btn">Search</button>
            <button id="reset_btn">Reset</button>
        </div>
    `;

    // Toggle panel behavior mock
    jQuery('#advanced_panel_onswitch').on('click', function() {
        const content = jQuery('#advanced_panel_content');
        if (content.css('display') === 'none') {
            content.css('display', 'block').addClass('in');
        } else {
            content.css('display', 'none').removeClass('in');
        }
    });
}

/**
 * Cleans up the URL query parameters after each test.
 */
function clearURL() {
    window.history.pushState(null, '', window.location.pathname);
}

test('SearchStateManager - Serialization', (t) => {
    setupDOM();
    clearURL();

    // Set some initial values
    jQuery('#test_name').val('Solanum');
    jQuery('#test_active').prop('checked', true);
    jQuery('#test_dropdown').val('val2');
    jQuery('input[name="test_multi"][value="banana"]').prop('checked', true);
    jQuery('input[name="test_multi"][value="cherry"]').prop('checked', true);

    const manager = create({
        submitButtonSelector: '#submit_btn',
        elements: {
            name: { selector: '#test_name' },
            active: { selector: '#test_active', type: 'checkbox' },
            dropdown: { selector: '#test_dropdown' },
            multi: { selector: 'input[name="test_multi"]', type: 'multi-checkbox' }
        }
    });

    const serialized = manager.serialize();

    t.equal(serialized.name, 'Solanum', 'Serializes text inputs correctly');
    t.equal(serialized.active, 'true', 'Serializes checked boolean state correctly');
    t.equal(serialized.dropdown, 'val2', 'Serializes select option values correctly');
    t.equal(serialized.multi, 'banana,cherry', 'Serializes multiple check arrays as comma-separated lists');
    
    t.end();
});

test('SearchStateManager - Custom Serialization (getValue)', (t) => {
    setupDOM();
    clearURL();

    let mockCustomValue = { internalKey: 'customData' };

    const manager = create({
        submitButtonSelector: '#submit_btn',
        elements: {
            custom_field: {
                selector: '#test_form',
                type: 'json',
                getValue: () => mockCustomValue
            }
        }
    });

    const serialized = manager.serialize();
    t.equal(
        serialized.custom_field,
        JSON.stringify(mockCustomValue),
        'Uses custom getValue hook to serialize complex nested objects as JSON strings'
    );

    t.end();
});

test('SearchStateManager - Deserialization & Element Updates', async (t) => {
    setupDOM();
    clearURL();

    // Populate query parameters to restore
    const url = new URL(window.location.href);
    url.searchParams.set('name', 'Lycopersicum');
    url.searchParams.set('active', 'true');
    url.searchParams.set('dropdown', 'val1');
    url.searchParams.set('multi', 'apple,cherry');
    window.history.pushState(null, '', url.pathname + url.search);

    const manager = create({
        submitButtonSelector: '#submit_btn',
        elements: {
            name: { selector: '#test_name' },
            active: { selector: '#test_active', type: 'checkbox' },
            dropdown: { selector: '#test_dropdown' },
            multi: { selector: 'input[name="test_multi"]', type: 'multi-checkbox' }
        }
    });

    await manager.deserialize();

    t.equal(jQuery('#test_name').val(), 'Lycopersicum', 'Restores text value correctly');
    t.ok(jQuery('#test_active').prop('checked'), 'Restores checked boolean state correctly');
    t.equal(jQuery('#test_dropdown').val(), 'val1', 'Restores drop down selection correctly');
    t.ok(jQuery('input[name="test_multi"][value="apple"]').prop('checked'), 'Restores multiple checkbox values (first match)');
    t.notOk(jQuery('input[name="test_multi"][value="banana"]').prop('checked'), 'Correctly leaves unrepresented checkboxes unchecked');
    t.ok(jQuery('input[name="test_multi"][value="cherry"]').prop('checked'), 'Restores multiple checkbox values (second match)');

    t.end();
});

test('SearchStateManager - Collapsible Parent Panel Auto-Expansion', async (t) => {
    setupDOM();
    clearURL();

    // Assert that the advanced panel container is closed initially
    t.equal(jQuery('#advanced_panel_content').css('display'), 'none', 'Collapsible container is initially closed');

    // Push an active search metric that lives inside the collapsible panel to the URL
    const url = new URL(window.location.href);
    url.searchParams.set('name', 'Solanum');
    window.history.pushState(null, '', url.pathname + url.search);

    const manager = create({
        submitButtonSelector: '#submit_btn',
        parentExpansionRules: {
            contentSuffix: '_content',
            toggleSuffix: '_onswitch'
        },
        elements: {
            name: { selector: '#test_name' }
        }
    });

    await manager.deserialize();

    t.equal(
        jQuery('#advanced_panel_content').css('display'),
        'block',
        'Collapsible parent container automatically expands when child element contains restored active parameters'
    );

    t.end();
});

test('SearchStateManager - Event Interception & Submission', async (t) => {
    setupDOM();
    clearURL();

    jQuery('#test_name').val('Tuberosum');

    let searchCallbackCalled = false;

    const manager = create({
        submitButtonSelector: '#submit_btn',
        onSearch: () => {
            searchCallbackCalled = true;
        },
        elements: {
            name: { selector: '#test_name' }
        }
    });

    await manager.init();

    // Trigger a click on the search submit button
    jQuery('#submit_btn').trigger('click');

    const updatedParams = new URLSearchParams(window.location.search);
    t.equal(updatedParams.get('name'), 'Tuberosum', 'Commits active states to the URL bar on click');
    t.ok(searchCallbackCalled, 'Executes the custom onSearch callback when search is submitted');

    t.end();
});

test('SearchStateManager - Resetting Form State', async (t) => {
    setupDOM();
    clearURL();

    // Setup active query params and run deserializer
    const url = new URL(window.location.href);
    url.searchParams.set('name', 'Capsicum');
    url.searchParams.set('active', 'true');
    window.history.pushState(null, '', url.pathname + url.search);

    let resetCallbackCalled = false;

    const manager = create({
        submitButtonSelector: '#submit_btn',
        resetButtonSelector: '#reset_btn',
        onReset: () => {
            resetCallbackCalled = true;
        },
        elements: {
            name: { selector: '#test_name' },
            active: { selector: '#test_active', type: 'checkbox' }
        }
    });

    await manager.init();
    jQuery('#reset_btn').trigger('click');

    t.equal(jQuery('#test_name').val(), '', 'Clears DOM text inputs on form reset');
    t.notOk(jQuery('#test_active').prop('checked'), 'Clears checkbox states on form reset');
    t.equal(window.location.search, '', 'Purges all managed search parameters from the URL query string');
    t.ok(resetCallbackCalled, 'Triggers the custom onReset callback when the form is cleared');

    t.end();
});
