#!/usr/bin/env node
'use strict';
/* Developer-only AST extraction. Application source is parsed as data, never loaded. */
const fs = require('node:fs');
const path = require('node:path');
let acorn;
try {
    const toolDependency = path.resolve(__dirname, 'node_modules/acorn');
    const projectDependency = path.resolve(__dirname, '../../js/node_modules/acorn');
    acorn = fs.existsSync(toolDependency) ? require(toolDependency) : fs.existsSync(projectDependency) ? require(projectDependency) : require('acorn');
    if (acorn.version !== '8.18.0') throw new Error('Expected qualified Acorn 8.18.0, found ' + acorn.version);
} catch (error) {
    process.stderr.write('Acorn extraction unavailable: ' + error.message + '\n');
    process.exit(1);
}
const MAX_SOURCE_BYTES = 8 * 1024 * 1024;

function childNodes(node) {
    const children = [];
    for (const [key, value] of Object.entries(node)) {
        if (key === 'loc' || key === 'start' || key === 'end') continue;
        if (Array.isArray(value)) {
            for (const item of value) if (item && typeof item.type === 'string') children.push(item);
        } else if (value && typeof value.type === 'string') children.push(value);
    }
    return children;
}
function unwrap(node) { return node && node.type === 'ChainExpression' ? unwrap(node.expression) : node; }
function propertyName(node) {
    node = unwrap(node);
    if (!node || node.type !== 'MemberExpression') return null;
    if (!node.computed && node.property.type === 'Identifier') return node.property.name;
    return node.computed && node.property.type === 'Literal' && typeof node.property.value === 'string' ? node.property.value : null;
}
function patternNames(node) {
    if (!node) return [];
    if (node.type === 'Identifier') return [node.name];
    if (node.type === 'AssignmentPattern') return patternNames(node.left);
    if (node.type === 'RestElement') return patternNames(node.argument);
    if (node.type === 'ArrayPattern') return node.elements.flatMap(patternNames);
    if (node.type === 'ObjectPattern') return node.properties.flatMap(item => patternNames(item.type === 'RestElement' ? item.argument : item.value));
    return [];
}
class Scope {
    constructor(parent, functionScope = false) { this.parent = parent; this.functionScope = functionScope; this.bindings = new Map(); }
    lookup(name) { return this.bindings.get(name) || (this.parent && this.parent.lookup(name)); }
    variableScope() { return this.functionScope || !this.parent ? this : this.parent.variableScope(); }
    declare(name, init, initScope, node) {
        let binding = this.bindings.get(name);
        if (!binding) { binding = {name, definitions: [], writes: [], resolving: false}; this.bindings.set(name, binding); }
        binding.definitions.push({init, scope: initScope, node});
        return binding;
    }
}

function extractBlock(block, file) {
    if (!block || typeof block.source !== 'string' || !Number.isSafeInteger(block.line_offset) || block.line_offset < 0 || !Array.isArray(block.masked_ranges || [])) throw new Error('Invalid JavaScript source block');
    if (Buffer.byteLength(block.source) > MAX_SOURCE_BYTES) throw new Error('JavaScript source block exceeds size limit');
    const ranges = block.masked_ranges || [];
    for (const range of ranges) if (!range || !Number.isSafeInteger(range.start) || !Number.isSafeInteger(range.end) || range.start < 0 || range.end <= range.start || range.end > block.source.length) throw new Error('Invalid Mason placeholder range');
    let ast;
    let scriptError;
    for (const sourceType of block.source_type === 'module' ? ['module'] : ['script', 'commonjs'].includes(block.source_type) ? ['script'] : ['script', 'module']) {
        try { ast = acorn.parse(block.source, {ecmaVersion: 'latest', sourceType, locations: true, allowReturnOutsideFunction: block.source_type === 'commonjs'}); break; }
        catch (error) { scriptError = scriptError || error; }
    }
    if (!ast) throw new Error(file + ':' + (block.line_offset + scriptError.loc.line) + ': JavaScript syntax error: ' + scriptError.message);
    const scopes = new WeakMap();
    const parents = new WeakMap();
    const nodes = [];
    const writes = [];
    const destructured = [];
    const propertyWrites = [];
    const root = new Scope(null, true);
    function visit(node, scope, parent = null) {
        if (parent) parents.set(node, parent);
        nodes.push(node);
        if (nodes.length > 1000000) throw new Error('JavaScript AST exceeds node limit');
        const functions = ['FunctionDeclaration', 'FunctionExpression', 'ArrowFunctionExpression'];
        if (node.type === 'FunctionDeclaration' && node.id) scope.declare(node.id.name, null, scope, node);
        if (node.type === 'ClassDeclaration' && node.id) scope.declare(node.id.name, null, scope, node);
        if (functions.includes(node.type)) {
            scope = new Scope(scope, true);
            if (node.type === 'FunctionExpression' && node.id) scope.declare(node.id.name, null, scope, node);
            for (const parameter of node.params) for (const name of patternNames(parameter)) scope.declare(name, null, scope, parameter);
        } else if (['BlockStatement', 'CatchClause', 'ForStatement', 'ForInStatement', 'ForOfStatement', 'SwitchStatement', 'ClassExpression'].includes(node.type)) {
            scope = new Scope(scope);
            if (node.type === 'CatchClause') for (const name of patternNames(node.param)) scope.declare(name, null, scope, node.param);
            if (node.type === 'ClassExpression' && node.id) scope.declare(node.id.name, null, scope, node);
        }
        scopes.set(node, scope);
        if (node.type === 'VariableDeclaration') {
            const target = node.kind === 'var' ? scope.variableScope() : scope;
            for (const declaration of node.declarations) {
                for (const name of patternNames(declaration.id)) target.declare(name, declaration.id.type === 'Identifier' ? declaration.init : null, scope, declaration);
                if (declaration.id.type !== 'Identifier' && declaration.init) destructured.push({node: declaration, scope});
            }
        }
        if (node.type === 'ImportDeclaration') for (const specifier of node.specifiers) scope.declare(specifier.local.name, null, scope, specifier);
        if (node.type === 'AssignmentExpression') for (const name of patternNames(node.left)) writes.push({name, scope, node, value: node.right});
        if (node.type === 'UpdateExpression') for (const name of patternNames(node.argument)) writes.push({name, scope, node, value: null});
        if (node.type === 'AssignmentExpression' && node.left.type === 'MemberExpression') propertyWrites.push({target: node.left, scope, node});
        if (node.type === 'UpdateExpression' && node.argument.type === 'MemberExpression') propertyWrites.push({target: node.argument, scope, node});
        for (const child of childNodes(node)) visit(child, scope, node);
    }
    visit(ast, root);
    for (const write of writes) {
        const binding = write.scope.lookup(write.name);
        if (binding) binding.writes.push(write);
    }
    function namespace(node, scope) {
        node = unwrap(node);
        if (!node) return false;
        if (node.type === 'Identifier' && node.name === 'SGN') return !scope.lookup('SGN');
        return propertyName(node) === 'SGN' && unwrap(node.object).type === 'Identifier' && ['window', 'globalThis'].includes(node.object.name) && !scope.lookup(node.object.name);
    }
    function fallback(node, scope) {
        node = unwrap(node);
        if (!node) return false;
        if (node.type === 'Literal' && node.value === null) return true;
        if (node.type === 'Identifier' && node.name === 'undefined') return !scope.lookup('undefined');
        return node.type === 'ObjectExpression' && node.properties.some(property => property.type === 'Property' && !property.computed && (property.key.name || property.key.value) === 'p' && ['FunctionExpression', 'ArrowFunctionExpression'].includes(property.value.type));
    }
    function combineKnown(states) { return states.some(value => value !== 'unknown'); }
    function bindingState(binding) {
        if (binding.resolving) return 'unknown';
        binding.resolving = true;
        const definitions = binding.definitions.map(item => item.init ? state(item.init, item.scope) : 'unknown');
        const assignments = binding.writes.map(item => item.value ? state(item.value, item.scope) : 'unknown');
        binding.resolving = false;
        if (!combineKnown(definitions.concat(assignments))) return 'unknown';
        if (binding.definitions.length !== 1 || binding.writes.length) return 'ambiguous';
        return definitions[0];
    }
    function state(node, scope) {
        node = unwrap(node);
        if (!node) return 'unknown';
        if (node.type === 'Identifier') {
            const binding = scope.lookup(node.name);
            return binding ? bindingState(binding) : 'unknown';
        }
        if (propertyName(node) === 'i18n' && namespace(node.object, scope)) return 'known';
        if (node.type === 'NewExpression' && propertyName(node.callee) === 'I18N' && namespace(node.callee.object, scope)) return 'known';
        if (node.type === 'LogicalExpression') {
            const left = state(node.left, scope), right = state(node.right, scope);
            if (node.operator === '&&' && namespace(node.left, scope) && right === 'known') return 'known';
            if (node.operator === '||' && left === 'known' && fallback(node.right, scope)) return 'known';
            return combineKnown([left, right]) ? 'ambiguous' : 'unknown';
        }
        if (node.type === 'MemberExpression') return state(node.object, scope) === 'unknown' ? 'unknown' : 'unsupported';
        if (node.type === 'CallExpression') return state(node.callee, scope) === 'unknown' ? 'unknown' : 'unsupported';
        if (node.type === 'ConditionalExpression' || node.type === 'SequenceExpression') return childNodes(node).some(child => state(child, scope) !== 'unknown') ? 'ambiguous' : 'unknown';
        return 'unknown';
    }
    function location(node) { return file + ':' + (block.line_offset + node.loc.start.line); }
    function rejectState(value, node) {
        if (value === 'ambiguous') throw new Error(location(node) + ': Ambiguous or reassigned translator alias');
        if (value === 'unsupported') throw new Error(location(node) + ': unsupported known i18n receiver chain');
    }
    for (const declaration of destructured) {
        if (state(declaration.node.init, declaration.scope) !== 'unknown') throw new Error(location(declaration.node) + ': unsupported translator destructuring');
    }
    function guardedGlobalFallback(write) {
        // Existing native save code initializes a plain fallback only when the
        // global translator is absent. Other property writes stay ambiguous.
        if (write.node.type !== 'AssignmentExpression' || write.node.operator !== '=' || propertyName(write.target) !== 'i18n' || !namespace(write.target.object, write.scope) || !fallback(write.node.right, write.scope)) return false;
        let child = write.node;
        for (let parent = parents.get(child); parent; child = parent, parent = parents.get(child)) {
            if (parent.type === 'IfStatement' && parent.consequent === child && parent.test.type === 'UnaryExpression' && parent.test.operator === '!') {
                const guard = unwrap(parent.test.argument);
                if (propertyName(guard) === 'i18n' && namespace(guard.object, scopes.get(parent))) return true;
            }
        }
        return false;
    }
    for (const write of propertyWrites) {
        if (state(write.target, write.scope) !== 'unknown' && !guardedGlobalFallback(write)) throw new Error(location(write.node) + ': Ambiguous or reassigned translator property');
    }
    const records = [];
    function literal(node, call) {
        if (!node || ranges.some(range => node.start < range.end && node.end > range.start)) throw new Error(location(call) + ': translation arguments must not contain dynamic Mason output');
        let value;
        if (node.type === 'Literal' && typeof node.value === 'string') value = node.value;
        else if (node.type === 'TemplateLiteral' && !node.expressions.length) value = node.quasis[0].value.cooked;
        else throw new Error(location(call) + ': translation arguments must be literal constants, not dynamic or concatenated expressions');
        if (typeof value !== 'string' || /[\u0000\u0004\uD800-\uDFFF]/u.test(value)) throw new Error(location(call) + ': invalid context or English text');
        return value;
    }
    for (const node of nodes) {
        if (node.type !== 'CallExpression') continue;
        const callee = unwrap(node.callee);
        const scope = scopes.get(node);
        if (callee.type === 'Identifier') { rejectState(state(callee, scope), node); continue; }
        if (callee.type !== 'MemberExpression') continue;
        const name = propertyName(callee);
        const receiver = state(callee.object, scope);
        if (!['p', 'np'].includes(name)) {
            if (name === null && receiver !== 'unknown') throw new Error(location(node) + ': dynamic known i18n method is unsupported');
            continue;
        }
        rejectState(receiver, node);
        if (receiver !== 'known') continue;
        const needed = name === 'p' ? 2 : 3;
        const args = node.arguments.slice(0, needed).map(argument => literal(argument, node));
        if (args.length !== needed || !args[1] || (needed === 3 && !args[2])) throw new Error(location(node) + ': invalid context or English text');
        records.push({context: args[0], source: args[1], plural: needed === 3 ? args[2] : null, reference: location(node)});
    }
    return records;
}

try {
    const raw = fs.readFileSync(0, 'utf8');
    if (Buffer.byteLength(raw) > MAX_SOURCE_BYTES * 2) throw new Error('JavaScript extraction request exceeds size limit');
    const request = JSON.parse(raw);
    if (!request || typeof request.file !== 'string' || !request.file || !Array.isArray(request.blocks) || request.blocks.length > 10000) throw new Error('Invalid JavaScript extraction request');
    const records = request.blocks.flatMap(block => extractBlock(block, request.file));
    process.stdout.write(JSON.stringify({schema: 1, parser: 'Acorn', parserVersion: acorn.version, records}) + '\n');
} catch (error) {
    process.stderr.write(String(error.message).slice(0, 1000) + '\n');
    process.exit(1);
}
