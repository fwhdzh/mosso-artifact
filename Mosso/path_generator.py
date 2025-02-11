import networkx as nx
import copy
import sys
import mosso
from heapq import heappush, heappop

def find_root(diGraph):
    node = None
    for n in diGraph.nodes(data=True):
        predecessors = diGraph.predecessors(n[0])
        if len(list(predecessors)) == 0:
            node = n
            break
    return node

def output(graph, output, tests):
    label = nx.get_node_attributes(graph, 'label')
    node_file = open(output+'.node','w')
    edge_file = open(output+'.edge','w')
    # Write all node information
    for i, node in enumerate(graph):
        if node.isdigit() or node.startswith('-'):
            node_file.write(node + ' ' + label[node] + '\n')
    # Write all edge information
    for path in tests:
        for i, node in enumerate(path):
            if i == 0:
                edge_file.write(node + ' ')
            else:
                action = graph[path[i-1]][node]['label']
                edge_file.write(action + ' ' + node + ' ')
        edge_file.write('\n')

def read_dot_file(file_path):
    return nx.drawing.nx_pydot.read_dot(file_path)

def get_initial_priority():
    return 100

def initialize_graph(graph):
    for _, _, data in graph.edges(data=True):
        data['priority'] = get_initial_priority()
        data['visited'] = False

def all_successors_visited(state, graph):
    for _, _, data in graph.edges(state, data=True):
        if not data['visited']:
            return False
    return True

def get_transition_with_highest_priority(state, graph):
    max_priority = -1
    selected_transition = None
    for u, v, data in graph.edges(state, data=True):
        if not data['visited'] and data['priority'] > max_priority:
            max_priority = data['priority']
            selected_transition = (u, v, data)
    return selected_transition

def update_priority(transition, redundant_transitions, graph):
    explored_trans = set()
    def recurse_update(trans):
        if trans not in explored_trans:
            explored_trans.add(trans)
            u, v, data = trans
            if (u, v) in redundant_transitions:
                data['priority'] /= 2
            for next_trans in redundant_transitions.get((u, v), []):
                recurse_update(next_trans)
    recurse_update(transition)

def traverse(state, path, graph, tests, end, redundant_transitions):
    if all_successors_visited(state, graph) or state == end:
        tests.add(copy.deepcopy(path))
        return

    while True:
        transition = get_transition_with_highest_priority(state, graph)
        if not transition:
            break
        u, v, data = transition
        data['visited'] = True
        data['priority'] = 0
        
        new_path = copy.deepcopy(path)
        new_path.append((u, v))

        update_priority((u, v, data), redundant_transitions, graph)
        traverse(v, new_path, graph, tests, end, redundant_transitions)

def prioritized_traversal(graph, init_state, end, redundant_transitions):
    tests = set()
    init_path = []
    initialize_graph(graph)
    traverse(init_state, init_path, graph, tests, end, redundant_transitions)
    return tests

"""
Main function
"""
def main():
    if (len(sys.argv) > 4):
        end = sys.argv[1]
        path = sys.argv[2]
        dir = sys.argv[3]
        rules = sys.argv[4]
    else:
        sys.exit(1)
    
    try:
        open(path)
    except IOError as e:
        sys.stderr.write("ERROR: could not read file" + path + "\n")
        sys.exit(1)

    G = nx.DiGraph(nx.drawing.nx_agraph.read_dot(path))
    print("Successfully read graph file.")

    n = nx.DiGraph.number_of_nodes(G)
    e = nx.DiGraph.number_of_edges(G)
    print("The graph contains", n, "nodes and", e, "edges.")

    root = find_root(G)
    print("Find the root node:", root[0])

    mosso.identify_redundant_state_transitions(G)
    mosso.identify_symmetric_state_transitions(G)
    mosso.identify_equivalent_state_transitions(G, rules)
    test_cases = prioritized_traversal(G, root, end, mosso.redundant_transitions)
    output(G, dir, test_cases)
