from docutils import nodes
from sphinx.domains import Domain
from sphinx.directives import ObjectDescription
from sphinx.roles import XRefRole
from sphinx.util.nodes import make_refnode


class SaltState(ObjectDescription):

    def handle_signature(self, sig, signode):
        signode += nodes.strong(text=sig)
        return sig


class SaltMacro(ObjectDescription):

    def handle_signature(self, sig, signode):
        signode += nodes.strong(text=sig)
        return sig


class SaltScript(ObjectDescription):

    def handle_signature(self, sig, signode):
        signode += nodes.strong(text=sig)
        return sig


class SaltDataFile(ObjectDescription):

    def handle_signature(self, sig, signode):
        signode += nodes.strong(text=sig)
        return sig


class SaltDomain(Domain):
    name = 'salt'
    label = 'Salt'
    directives = {
        'state': SaltState,
        'macro': SaltMacro,
        'script-py': SaltScript,
        'script-sh': SaltScript,
        'data-file': SaltDataFile,
    }
    roles = {
        'state': XRefRole(),
        'macro': XRefRole(),
        'data': XRefRole(),
        'script': XRefRole(),
        'config': XRefRole(),
    }
    initial_data = {
        'states': {},
        'macros': {},
        'scripts': {},
        'data_files': {},
        'configs': {},
    }

    def get_full_qualified_name(self, node):
        return f'{node.arguments[0]}'

    def resolve_xref(self, env, fromdocname, builder, typ, target, node, contnode):
        docname = None
        prefix_map = {'state': 'state', 'macro': 'macro', 'data': 'data-file',
                      'script': 'script', 'config': 'config'}
        target_id = f'{prefix_map.get(typ, typ)}-{target}'
        for doc in env.found_docs:
            if doc.startswith('states/') and typ == 'state' and doc.endswith(target.replace('.', '-')):
                docname = doc
                break
            if doc.startswith('macros/') and typ == 'macro' and doc.endswith(target.replace('.', '-')):
                docname = doc
                break
            if doc.startswith('data-files/') and typ == 'data' and doc.endswith(target.replace('/', '-')):
                docname = doc
                break
        if docname is None:
            tentative = f'{typ}s/{target}'
            if tentative in env.found_docs:
                docname = tentative
        if docname:
            return make_refnode(builder, fromdocname, docname, target_id, contnode, target)
        return None

    def resolve_any_xref(self, env, fromdocname, builder, target, node, contnode):
        for role_name in ('state', 'macro', 'data', 'script', 'config'):
            result = self.resolve_xref(env, fromdocname, builder, role_name, target, node, contnode)
            if result:
                return [('salt:' + role_name, result)]
        return []


def setup(app):
    app.add_domain(SaltDomain)
