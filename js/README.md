# Javascript in SGN

The new JavaScript system in SGN relies on Webpack, Node, and NPM. The new system allows for the use of node modules and for ES6 module imports to be resolved and bundled into an efficient number of javascript files.

To install Node.js and NPM run `./install_node.sh` as root.

In order to hook into Catalyst, Mason, and the rest of the SGN infrastructure, Webpack has been configured in a slightly atypical manner. In a typical Webpack setup, there is a JavaScript file for each page. However, with the way our legacy code is structured, this paradigm would require a large amount of refactoring. So, instead, Webpack is configured such that modern JavaScript is transpiled into separate (independently loadable) namespaces within a multi-part library call 'jsMod'.

The following three sections will enumerate the different locations one can use JavaScript on the site, and how they behave.

## On-Page JavaScript
The most obvious JavaScript on the site is directly within a `<script>` tag in a Mason file. Code here is NOT touched by any JavaScript transpilers, minifiers, or by webpack. Any JavaScript written directly into the page will be transmitted to the user as-is. This means that the author of said code MUST be careful to use only ES2015 JavaScript functionality. Some things which are inappropriate for On-Page JavaScript include arrow functions (`()=>{}`) and ES6 classes (`class ClassName{}`).

## Legacy JavaScript
#### `legacy`
Legacy JavaScript is, for our purposes, all JavaScript files which are managed by the `JSAN.use("")` dependency system. This means all JavaScript files previously stored in the `js/` directory. Because of important global side-effects cause by the common use of global scope definitions in these files, it is very difficult (likely impossible) to automatically convert them to a state such that Webpack is able to properly handle their interdependence (and the On-Page JavaScript which depends on their globally defined variables). As such, legacy code has been "quarantined" in the `js/source/legacy` folder. Any code in this folder continues to behave exactly as it would have before the addition of the Webpack system. As such, **legacy code is executed in the global scope, and adding to it should be avoided.** Legacy JavaScript is minified using a  _legacy minifier_ and like On-Page JavaScript, is not transpiled, this means that the author of said code MUST be careful to use only ES2015 JavaScript functionality. Failing to do so may break the minification step, or lead to incompatibilities with users' browsers. To include legacy JS on a page, one should use the following pattern:

| File Paths | Mason Pattern | 
| --------- | ------------- |
| `js/source/legacy/CXGN/Effects.js`, `js/source/legacy/CXGN.Phenome/Locus.js`, `js/source/legacy/MochiKit/DOM.js` | `<& /util/import_javascript, legacy => [ "CXGN.Effects", "CXGN.Phenome.Locus", "MochiKit.DOM" ] &>` |


## Modern JavaScript
Modern JavaScript is defined in this documentation as source for the webpack pre-comiler. Modern JavaScript is transpiled and polyfilled to allow for the use of newer JavaScript features without worrying as much about reverse compatibility. Having added a transpilation step, we can take advantage of this existing overhead by also using Webpack to resolve and bundle dependencies. This allows us to use ES6 module imports and exports. Because webpack relies on an "Entry" model, we have two main folders of Modern JavaScript files. 

#### `entries`

The first folder is `js/source/entries`. This contains a JS module which describes a namespace of the `jsMod` global object.

For example:
```js
// js/source/entries/example.js
var someVariableName = "someValue";
export someVariableName;
```
```html
<!-- mason/**/example.mas -->
<& /import_javascript, entries => ["example.js"]&>
<script type="text/javascript">
  // Writes to console:
  console.log(someVariableName===undefined);
  // -> true
  console.log(jsMod['example'].someVariableName);
  // -> "someValue"
</script>

```

#### `modules`

The next is `js/source/modules`. This contains a JS module which is not exposed via jsMod, but whose code can be imported by multiple `entries`. `modules` differ from `entires` in that, if a `entries` file imports another `entries` file, the included entry will be sent to the user as a separate file. If a `entries` file imports a `modules` file, however, that module will be bundled into the same file as the entry when being sent to the user. Further, if some set of `modules` files are commonly imported by multiple `entries`, they will be bundled together as a file such that they might be cached for later use by the user's browser. [Click here for more information on that process.](https://webpack.js.org/guides/code-splitting/) Remember, `modules` files are not exposed via the `jsMod` object.  

For example:
```js
// js/source/modules/example0.js
var myVar = "aValue";
export myVar;
```
```js
// js/source/entries/example1.js
import {myVar} from '../modules/example0.js';
var yetAnother = "someValue";
export yetAnother;
export var someVar = myVar;
```
```html
<!-- mason/**/example.mas -->
<& /import_javascript, entries => ["example1.js"]&>
<script type="text/javascript">
  // Writes to console:
  console.log(myVar===undefined);
  // -> true
  console.log(yetAnother===undefined);
  // -> true
  console.log(jsMod['example0']===undefined);
  // -> true
  console.log(jsMod['example1'].yetAnother);
  // -> "someValue"
  console.log(jsMod['example1'].myVar===undefined);
  // -> true
  console.log(jsMod['example1'].someVar);
  // -> "aValue"
</script>

```

## Combining Legacy and Modern JS

Legacy JS cannot import or depend on Modern JS and is always executed first. Modern JS can import legacy code for global effects (aka side-effects) by specifying the relative path to the file (e.g. `import "../legacy/CXGN/Phenome/Locus.js";`). JSAN dependencies declared in legacy code _will_ be resolved. 

`/util/import_javascript` can also import legacy code and entry modules in one statement. `<& /import_javascript, entries => [], legacy => [] &>`

## JavaScript Testing

#### `tests`

Tests are run via `node js/run-tests.js`. This script outputs TAP in stdout and other test script JS console output as stderr. Each file in the `js/test` directory is run in a separate virtual DOM. The tests are run using [jsdom](https://github.com/jsdom/jsdom), [tape](https://github.com/substack/tape), and [nock](https://github.com/nock/nock). 

#### [jsdom](https://github.com/jsdom/jsdom)
Provides the virtual DOM that tests run within. This enables tests to act as though they are running in a browser, without requiring the overhead of a system like selenium. However, there is no _rendering_– only the DOM is managed. Typical global browser variables such as `window` and `browser` are available. If you are only adding tests, you shouldn't need to interact with JSDOM functionality in any direct way.

#### [tape](https://github.com/substack/tape)
The test harness used is [tape](https://github.com/substack/tape). It was chosen due to its extraordinary flexibility. The [tape documentation](https://github.com/substack/tape) goes over much of the functionality. 

#### Putting tape and jsdom Together

- Files to be tested should be imported as one would in a source file: 
  ```js
  // test/example.test.js[0:1]
  import * as Boxplotter from '../source/entries/boxplotter.js';
  ```  
- In order to run tests, you can set the contents of the DOM like you might in the browser:
  ```js
  // test/example.test.js[1:2]
  document.querySelector('body').innerHTML = `<div id="bxplt"></div>`;
  ```
- These can then be tested using the tape harness:
  ```js
  // test/example.test.js[2:8]
  test("Boxplotter", t=>{
        t.plan(1);
        t.doesNotThrow(()=>{
            boxplotter = Boxplotter.init("#bxplt");
        })
    });
  ```

#### [nock](https://github.com/nock/nock)
[nock](https://github.com/nock/nock) provides server mocking for testing JS with we requests. By default, test scripts cannot make we requests. You have two options to fix this. 
- Create a [nock interceptor](https://github.com/nock/nock#read-this---about-interceptors) like so:
  ```js
  var scope = nock(document.location.origin);
  test("Test Web Request", t=>{
      t.plan(1);
      scope.get('/testurl').reply(200, {'yourdata':'here'});
      fetch(document.location.origin+'/testurl')
        .then(resp=>resp.json())
        .then(data=>{
          t.equals(data.yourdata,'here');
        });
  });
  ```
- [Enable external web requests](https://github.com/nock/nock#enabling-requests) for your test file like so:
  ```js
  nock.enableNetConnect('cassavabase.org')
  test("Test Web Request", t=>{
      t.plan(1);
      fetch('https://cassavabase.org/realurl')
        .then(resp=>resp.json())
        .then(data=>{
          t.equals(data.yourdata,'here');
        });
  });
  ```
