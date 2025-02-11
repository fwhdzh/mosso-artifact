import networkx as nx

redundant_transitions = set()

def independent(tranA, tranB, graph):
    end_state_A = tranA[1]
    end_state_B = tranB[1]
    for succA in graph.successors(end_state_A):
        for succB in graph.successors(end_state_B):
            actionA = graph[end_state_A][succA].get('action')
            actionB = graph[end_state_B][succB].get('action')
            if succA == succB and actionA == tranB[2]['action'] and actionB == tranA[2]['action']:
                return (succA, succB)
    return None

def identify_redundant_state_transitions(graph):
    for state in graph.nodes():
        successors = list(graph.successors(state))
        for i in range(len(successors)):
            for j in range(i + 1, len(successors)):
                tranA = (state, successors[i], graph[state][successors[i]])
                tranB = (state, successors[j], graph[state][successors[j]])
                result = independent(tranA, tranB, graph)
                if result is not None:
                    succA, succB = result
                    redundant_transitions.add((tranA, succB))
                    redundant_transitions.add((tranB, succA))

def is_state_symmetric(stateA, stateB, mapping, nodes):
    for varA in stateA['variables']:
        varB = stateB['variables'][varA['index']]
        if varA['type'] == 'state-related':
            for node in varA['nodes']:
                if not (node, macth(varB[node, varA[node]])) in mapping.items():
                    return False
        elif varA['type'] == 'message-related':
            if varA['size'] != varB['size']:
                return False
            for msg in varA:
                if not (msg, varB['mapped'][msg['src'], msg['dst'], msg['type'], msg['values']]) in mapping.items():
                    return False
    return True

def is_action_symmetric(actionA, actionB, mapping):
    if actionA['name'] != actionB['name']:
        return False
    for paraA in actionA['parameters']:
        paraB = actionB['parameters'][paraA.index]
        if paraA['type'] == 'node ID':
            if not (paraA, paraB) in mapping.items():
                return False
        elif paraA['type'] == 'message element':
            if not ((paraA['src'], paraB['src']) in mapping.items() and
                    (paraA['dst'], paraB['dst']) in mapping.items() and
                    paraA['type'] == paraB['type'] and
                    paraA['values'] == paraB['values']):
                return False
    return True

def get_symmetry_mapping(stateA, stateB):
    mapping = {}
    for varA in stateA['variables']:
        varB = stateB['variables'][varA.index]
        if varA['type'] == 'state-related':
            for node in varA['nodes']:
                if varB[node, varA[node]]:
                    mapping[node] = match(varB[node, varA[node]])
                else:
                    return None
        elif varA['type'] == 'message-related':
            if varA['size'] != varB['size']:
                return None
            for msg in varA:
                if varB['mapped'][msg['src'], msg['dst'], msg['type'], msg['values']]:
                    mapping[msg] = varB['mapped'][msg['src'], msg['dst'], msg['type'], msg['values']]
                else:
                    return None
    return mapping

def identify_symmetric_state_transitions(graph):
    for tranA in graph.edges(data=True):
        for tranB in graph.edges(data=True):
            if tranA == tranB:
                continue
            stateA_start = tranA[0]
            stateB_start = tranB[0]
            mapping = get_symmetry_mapping(graph.nodes[stateA_start], graph.nodes[stateB_start])
            if mapping and is_state_symmetric(graph.nodes[tranA[1]], graph.nodes[tranB[1]], mapping) and is_action_symmetric(tranA[2]['action'], tranB[2]['action'], mapping):
                redundant_transitions.add((tranA, tranB))

def parse_rules(rule_file_path):
    rules = []
    with open(rule_file_path, 'r') as file:
        content = file.read()
        
    state_rule_pattern = re.compile(r'rule_state_(\w+):\n(.*?)\n\n', re.DOTALL)
    action_rule_pattern = re.compile(r'rule_action_(\w+):\n\{(.*?)\}\n\n', re.DOTALL)
    
    state_rules = state_rule_pattern.findall(content)
    action_rules = action_rule_pattern.findall(content)
    
    for state_rule, action_rule in zip(state_rules, action_rules):
        state_rule_name, state_rule_body = state_rule
        action_rule_name, action_rule_body = action_rule
        
        if state_rule_name != action_rule_name:
            raise ValueError("State rule and action rule names do not match")
        
        rules.append({
            'state': compile_state_rule(state_rule_body),
            'action': parse_action_rule(action_rule_body)
        })
    return rules

def compile_state_rule(rule_body):
    def state_equivalence_rule(A, B):
        ret = True
        exec(rule_body, {'A': A, 'B': B, 'ret': ret, 'Nodes': range(len(A['term']))}, locals())
        return ret
    return state_equivalence_rule

def parse_action_rule(action_rule_body):
    actions = set()
    for action in action_rule_body.split(','):
        action = action.strip()
        if '(' in action and ')' in action:
            action_name = action.split('(')[0]
            actions.add((action_name, True))
        else:
            actions.add((action, False))
    return actions

def equivalent(tranA, tranB, rules, graph):
    ret = False
    for rule in rules:
        stateA_start = graph.nodes[tranA[0]]
        stateB_start = graph.nodes[tranB[0]]
        stateA_end = graph.nodes[tranA[1]]
        stateB_end = graph.nodes[tranB[1]]
        actionA = tranA[2]['action']
        actionB = tranB[2]['action']
        
        ret = ret or (
            rule['state'](stateA_start, stateB_start) and
            rule['state'](stateA_end, stateB_end) and
            actionA == actionB and
            not any(action == actionA and param in action for action, param in rule['action'])
        )
    return ret

def identify_redundant_state_transitions(graph, rules):
    redundant_transitions = set()
    for tranA in graph.edges(data=True):
        for tranB in graph.edges(data=True):
            if tranA == tranB:
                continue
            if equivalent(tranA, tranB, rules, graph):
                redundant_transitions.add((tranA, tranB))
    return redundant_transitions