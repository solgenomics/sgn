"""Bounded GNU gettext plural grammar shared by build and installation tools.

The parser emits the same data-only tree as SGN's pinned Jed runtime. It never
executes a catalog expression and requires neither Node nor application source.
"""

import re

MAX_INTEGER = 9007199254740991
BINARY = {
    "||": (1, "OR"),
    "&&": (2, "AND"),
    "<": (3, "LT"),
    "<=": (3, "LTE"),
    ">": (3, "GT"),
    ">=": (3, "GTE"),
    "==": (3, "EQ"),
    "!=": (3, "NEQ"),
    "%": (4, "MOD"),
}
TOKEN = re.compile(r"[ \t\r\n]*([0-9]+|n|\|\||&&|<=|>=|==|!=|[()?:%<>])")


# JSON booleans are not integer grammar constants.
# pylint: disable=unidiomatic-typecheck
def validate_ast(node, depth=0, count=None):
    """Reject unknown fields, oversized trees and noninteger constants."""
    count = [0] if count is None else count
    count[0] += 1
    if depth > 24 or count[0] > 128 or not isinstance(node, dict):
        raise ValueError("plural AST exceeds limits")
    kind = node.get("type")
    fields = {
        "VAR": (),
        "NUM": ("val",),
        "GROUP": ("expr",),
        "TERNARY": ("expr", "truthy", "falsey"),
        **{name: ("left", "right") for _, name in BINARY.values()},
    }
    if kind not in fields or set(node) != {"type", *fields[kind]}:
        raise ValueError("unsupported plural AST node")
    if kind == "NUM":
        if type(node["val"]) is not int or not 0 <= node["val"] <= MAX_INTEGER:
            raise ValueError("invalid plural constant")
    else:
        for field in fields[kind]:
            validate_ast(node[field], depth + 1, count)


# pylint: enable=unidiomatic-typecheck


def validate_bounds(node, nplurals):
    """Prove modulo safety and form bounds for every nonnegative safe count."""

    def bounds(item):
        kind = item["type"]
        if kind == "NUM":
            return item["val"], item["val"]
        if kind == "VAR":
            return 0, MAX_INTEGER
        if kind == "GROUP":
            return bounds(item["expr"])
        if kind == "TERNARY":
            bounds(item["expr"])
            left, right = bounds(item["truthy"]), bounds(item["falsey"])
            return min(left[0], right[0]), max(left[1], right[1])
        left = bounds(item["left"])
        bounds(item["right"])
        if kind == "MOD":
            divisor = item["right"]
            while divisor["type"] == "GROUP":
                divisor = divisor["expr"]
            if divisor["type"] != "NUM" or divisor["val"] <= 0:
                raise ValueError("plural modulo divisor must be a positive integer constant")
            return 0, min(left[1], divisor["val"] - 1)
        return 0, 1

    low, high = bounds(node)
    if low < 0 or high >= nplurals:
        raise ValueError("plural index cannot be proven inside the catalog form count")


class Parser:
    """Small precedence parser for the explicitly supported GNU grammar."""

    def __init__(self, expression):
        self.tokens = []
        cursor = 0
        expression = expression.strip()
        while cursor < len(expression):
            match = TOKEN.match(expression, cursor)
            if not match:
                raise ValueError("unsupported or unsafe plural expression")
            self.tokens.append(match[1])
            cursor = match.end()
        if not self.tokens or len(self.tokens) > 256:
            raise ValueError("plural expression exceeds token limits")
        self.position = 0

    def peek(self):
        """Return the next grammar token, or no token at EOF."""
        return self.tokens[self.position] if self.position < len(self.tokens) else None

    def take(self, wanted=None):
        """Consume one token after checking the required delimiter."""
        token = self.peek()
        if token is None or (wanted is not None and token != wanted):
            raise ValueError("unsupported or unsafe plural expression")
        self.position += 1
        return token

    def expression(self, minimum=0, depth=0):
        """Parse left-associative binaries and right-associative ternaries."""
        if depth > 24:
            raise ValueError("plural expression exceeds depth limits")
        token = self.take()
        if token == "(":
            left = {"type": "GROUP", "expr": self.expression(depth=depth + 1)}
            self.take(")")
        elif token == "n":
            left = {"type": "VAR"}
        elif token.isdecimal():
            left = {"type": "NUM", "val": int(token)}
        else:
            raise ValueError("unsupported or unsafe plural expression")
        while self.peek() in BINARY and BINARY[self.peek()][0] >= minimum:
            precedence, kind = BINARY[self.take()]
            right = self.expression(precedence + 1, depth + 1)
            left = {"type": kind, "left": left, "right": right}
        if minimum == 0 and self.peek() == "?":
            self.take("?")
            truthy = self.expression(depth=depth + 1)
            self.take(":")
            falsey = self.expression(depth=depth + 1)
            left = {"type": "TERNARY", "expr": left, "truthy": truthy, "falsey": falsey}
        return left


def parse_plural(expression):
    """Compile a bounded header to the exact SGN browser/runtime AST shape."""
    if not isinstance(expression, str) or len(expression) > 512:
        raise ValueError("plural expression too large or invalid")
    match = re.fullmatch(r"\s*nplurals\s*=\s*([1-6])\s*;\s*plural\s*=\s*([^;]+?)\s*;?\s*", expression)
    if not match:
        raise ValueError("unsupported or unsafe plural expression")
    parser = Parser(match[2])
    node = {"type": "GROUP", "expr": parser.expression()}
    if parser.peek() is not None:
        raise ValueError("unsupported or unsafe plural expression")
    validate_ast(node)
    nplurals = int(match[1])
    validate_bounds(node, nplurals)
    return {"nplurals": nplurals, "ast": node, "normalized": f"nplurals={nplurals}; plural={match[2].strip()};"}
