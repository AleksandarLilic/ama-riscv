#!/usr/bin/env python3

import argparse
import json
import sys

# verilog literal base letter -> int base, for decoding parameter values
BASES = {"b": 2, "o": 8, "d": 10, "h": 16}

# one nesting level of plain indentation (default, foldable) output
INDENT = "    "

def child_instances(body):
    """Direct child module instances of an InstanceBody. Generate blocks/arrays
    are flattened, but their scope is kept as a Vivado-style prefix on the
    instance name (gen_blk.inst, gen_arr[i].inst), so generate-for repeats stay
    distinct. Returns [(qualified_inst_name, module_name, child_body), ...]."""

    out = []

    def descend(members, scope):
        for m in members:
            k = m.get("kind")
            if k == "Instance":
                # an Instance carries its elaborated module in .body
                b = m.get("body", {})
                out.append((scope + m.get("name"), b.get("name"), b))
            elif k == "GenerateBlock":
                # generate-if: qualify by the block label (gen_xxx.); fall back
                # to [constructIndex] for an unnamed per-iteration block
                nm, idx = m.get("name"), m.get("constructIndex")
                if nm:
                    pre = f"{nm}."
                elif idx is not None:
                    pre = f"[{idx}]."
                else:
                    pre = ""
                descend(m.get("members", []), scope + pre)
            elif k == "GenerateBlockArray":
                # generate-for: each iteration is an unnamed GenerateBlock under
                # the array label; qualify as <label>[i].
                arr = m.get("name")
                for el in m.get("members", []):
                    if el.get("kind") == "GenerateBlock":
                        descend(el.get("members", []),
                                f"{scope}{arr}[{el.get('constructIndex')}].")
            elif k == "InstanceArray":
                descend(m.get("members", []), scope)

    descend(body.get("members", []), "")
    return out

def fmt_param(v):
    """Decode a verilog literal (32'd32, 1'b1, 32'sb01101) to a plain int
    string; leave non-numeric values (e.g. a type name) untouched."""
    s = str(v).strip()
    if "'" in s:
        _, _, lit = s.partition("'") # keep the base+digits after the quote
        lit = lit.lstrip("sS") # drop the optional signed marker
        base = BASES.get(lit[:1].lower())
        if base is not None:
            try:
                return str(int(lit[1:].replace("_", ""), base))
            except ValueError:
                pass
    return s

def param_str(body):
    """Public (non-local) instantiation parameters of an instance body, as
    'P1=v1, P2=v2'; empty when the module takes no parameters."""
    ps = [(p["name"], fmt_param(p.get("value")))
          for p in body.get("members", [])
          if p.get("kind") == "Parameter" and not p.get("isLocal")]
    return ", ".join(f"{n}={v}" for n, v in ps)

def find_root(design, root_name):
    """Return (instance_name, body) for the requested root (or the elaboration
    top if root_name is None)."""
    tops = [m for m in design.get("members", []) if m.get("kind") == "Instance"]
    if not tops:
        sys.exit("no top-level instance found in AST")
    if root_name is None:
        return tops[0]["name"], tops[0]["body"]

    def search(body):
        for iname, mname, b in child_instances(body):
            if mname == root_name:
                return iname, b
            hit = search(b)
            if hit:
                return hit
        return None

    for top in tops:
        if top["body"].get("name") == root_name:
            return top["name"], top["body"]
        hit = search(top["body"])
        if hit:
            return hit
    sys.exit(f"root module '{root_name}' not found in hierarchy")

def render(top_body, instances=False, keep=None, params=False, tree=False):
    """Build the tree lines and the total instance count."""
    out = []
    total = [0]

    def visible(kids):
        # drop interface instances unless filtering is off (keep is None)
        if keep is None:
            return kids
        return [(i, m, b) for (i, m, b) in kids if m in keep]

    def label_of(mname, body):
        # module name, annotated with its parameters under --params
        if params:
            ps = param_str(body)
            if ps:
                return f"{mname} ({ps})"
        return mname

    def walk(label, body, prefix, is_last, top=False):
        # tree mode draws connectors; indent mode (default) uses plain spaces
        # so editors can fold the hierarchy by indentation on large designs
        if top:
            out.append(label)
            child_prefix = "" if tree else INDENT
        elif tree:
            out.append(prefix + ("└── " if is_last else "├── ") + label)
            child_prefix = prefix + ("    " if is_last else "│   ")
        else:
            out.append(prefix + label)
            child_prefix = prefix + INDENT

        kids = visible(child_instances(body))
        if instances:
            # one line per instance: 'inst (module)'; --params nests the
            # module's own '(params)' -> 'inst (module (params))', matching
            # the collapsed view
            items = [(f"{cin} ({label_of(cmn, cb)})", cb)
                     for cin, cmn, cb in kids]
            total[0] += len(kids)
        else:
            # collapse identical siblings; the group key includes the params
            # under --params, so differing-param instances stay separate
            order, groups = [], {}
            for cin, cmn, cb in kids:
                key = (cmn, param_str(cb)) if params else cmn
                if key not in groups:
                    groups[key] = [cmn, cb, 0]
                    order.append(key)
                groups[key][2] += 1
            items = []
            for key in order:
                cmn, cb, n = groups[key]
                total[0] += n
                lbl = label_of(cmn, cb) + (f"  x{n}" if n > 1 else "")
                items.append((lbl, cb))

        for i, (lbl, cb) in enumerate(items):
            walk(lbl, cb, child_prefix, i == len(items) - 1)

    walk(label_of(top_body.get("name"), top_body), top_body, "", True, top=True)
    return out, total[0]

def render_dot(top_body, keep=None):
    """Graphviz module-dependency graph: one node per module, an edge per
    'parent instantiates child' (labelled xN when instantiated more than once).
    Containment/block view, not net-level connectivity."""
    nodes = [] # unique module names, first-seen order
    edges = {} # (parent, child) -> instance count
    seen = set() # modules already expanded (DAG: expand each once)

    def visit(mname, body):
        if mname not in seen:
            seen.add(mname)
            nodes.append(mname)
        kids = child_instances(body)
        if keep is not None:
            kids = [(i, m, b) for (i, m, b) in kids if m in keep]

        order, bodies, cnt = [], {}, {}
        for _, cmn, cb in kids:
            if cmn not in cnt:
                order.append(cmn)
                bodies[cmn] = cb
                cnt[cmn] = 0
            cnt[cmn] += 1

        for cmn in order:
            # record the edge before recursing so multi-parent edges all land
            edges[(mname, cmn)] = edges.get((mname, cmn), 0) + cnt[cmn]
            if cmn not in seen:
                visit(cmn, bodies[cmn])

    visit(top_body.get("name"), top_body)
    out = ["digraph hier {", "  rankdir=LR;", "  node [shape=box];"]
    out += [f'  "{n}";' for n in nodes]
    for (p, c), n in edges.items():
        lbl = f' [label="x{n}"]' if n > 1 else ""
        out.append(f'  "{p}" -> "{c}"{lbl};')
    out.append("}")
    return out

def parse_args():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=("Render the module instantiation hierarchy from a slang --ast-json dump."),
        epilog=(
            "examples:\n"
            "  slang ... --top <top> --ast-json - | slang_hier.py [opts]\n"
            "  slang_hier.py ast.json --params --tree")
        )
    parser.add_argument("ast", nargs="?", help="AST json file; reads stdin if omitted")
    parser.add_argument("--root", metavar="MODULE", help="start the tree at the first instance of MODULE (default: elaboration top)")
    parser.add_argument("--instances", action="store_true", help="list every instance, no collapsing")
    parser.add_argument("--params", action="store_true", help="annotate modules with parameter values (differing-param instances stay separate when collapsed)")
    parser.add_argument("--interfaces", action="store_true", help="include SV interface instances (default: modules only)")
    parser.add_argument("--tree", action="store_true", help="box-drawing connectors instead of the default plain indentation")
    parser.add_argument("--dot", action="store_true", help="emit a Graphviz module-dependency graph instead of a text tree")
    args = parser.parse_args()

    # no file and stdin is a terminal -> json.load would block forever; bail
    if args.ast is None and sys.stdin.isatty():
        parser.error("no input: give an AST file or pipe 'slang --ast-json -'")
    return args

def main():
    args = parse_args()
    src = open(args.ast) if args.ast else sys.stdin
    ast = json.load(src)
    design = ast.get("design", ast) # tolerate a bare Root too

    keep = None
    if not args.interfaces:
        # restrict to module instances; interfaces are a separate definitionKind
        mods = {d["name"] for d in ast.get("definitions", [])
                if d.get("definitionKind") == "Module"}
        keep = mods or None # bare Root has no defs -> can't filter, show all

    _, body = find_root(design, args.root)
    if args.dot:
        print("\n".join(render_dot(body, keep=keep)))
        return
    lines, total = render(
        body, instances=args.instances, keep=keep, params=args.params,
        tree=args.tree
    )
    print("\n".join(lines))
    kind = "instances" if args.instances else "instances (collapsed)"
    print(f"\n{total} {kind}")

if __name__ == "__main__":
    main()
