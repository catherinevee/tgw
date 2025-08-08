#!/usr/bin/env python3
"""
Custom Blast Radius - Interactive Terraform Dependency Visualizer

A tool for creating interactive visualizations of Terraform dependency graphs
using d3.js and Graphviz for layout.
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
import networkx as nx
import hcl2
from flask import Flask, render_template, request, jsonify, send_from_directory
import graphviz


class BlastRadius:
    """Main Blast Radius application class."""
    
    def __init__(self):
        self.app = Flask(__name__)
        self.graph_data = None
        self.terraform_path = None
        
    def parse_terraform(self, path: str) -> Dict[str, Any]:
        """Parse Terraform configuration files and extract resource dependencies."""
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"Path not found: {path}")
            
        resources = {}
        data_sources = {}
        modules = {}
        
        # Find all .tf files
        tf_files = list(path.rglob("*.tf"))
        if not tf_files:
            raise ValueError(f"No Terraform files found in {path}")
            
        print(f"Found {len(tf_files)} Terraform files")
        
        for tf_file in tf_files:
            try:
                with open(tf_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Parse HCL2
                parsed = hcl2.loads(content)
                
                # Extract resources
                if 'resource' in parsed:
                    for resource_type, resource_instances in parsed['resource']:
                        for resource_name, resource_config in resource_instances:
                            full_name = f"{resource_type}.{resource_name}"
                            resources[full_name] = {
                                'type': resource_type,
                                'name': resource_name,
                                'file': str(tf_file.relative_to(path)),
                                'config': resource_config,
                                'dependencies': self._extract_dependencies(resource_config)
                            }
                
                # Extract data sources
                if 'data' in parsed:
                    for data_type, data_instances in parsed['data']:
                        for data_name, data_config in data_instances:
                            full_name = f"data.{data_type}.{data_name}"
                            data_sources[full_name] = {
                                'type': data_type,
                                'name': data_name,
                                'file': str(tf_file.relative_to(path)),
                                'config': data_config,
                                'dependencies': self._extract_dependencies(data_config)
                            }
                
                # Extract modules
                if 'module' in parsed:
                    for module_name, module_config in parsed['module']:
                        modules[module_name] = {
                            'name': module_name,
                            'file': str(tf_file.relative_to(path)),
                            'config': module_config,
                            'dependencies': self._extract_dependencies(module_config)
                        }
                        
            except Exception as e:
                print(f"Warning: Error parsing {tf_file}: {e}")
                continue
                
        return {
            'resources': resources,
            'data_sources': data_sources,
            'modules': modules,
            'path': str(path)
        }
    
    def _extract_dependencies(self, config: Dict[str, Any]) -> List[str]:
        """Extract resource dependencies from configuration."""
        dependencies = []
        
        def extract_refs(obj):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if key == 'source' and isinstance(value, str):
                        # Module source
                        dependencies.append(value)
                    elif isinstance(value, str) and value.startswith(('${', 'data.', 'module.')):
                        # Resource references
                        ref = value.strip('${}')
                        if ref.startswith(('data.', 'module.')):
                            dependencies.append(ref)
                    elif isinstance(value, (dict, list)):
                        extract_refs(value)
            elif isinstance(obj, list):
                for item in obj:
                    extract_refs(item)
                    
        extract_refs(config)
        return list(set(dependencies))
    
    def generate_graph(self, data: Dict[str, Any]) -> nx.DiGraph:
        """Generate a NetworkX directed graph from Terraform data."""
        G = nx.DiGraph()
        
        # Add nodes for all resources
        for resource_name, resource_info in data['resources'].items():
            G.add_node(resource_name, 
                      type='resource',
                      resource_type=resource_info['type'],
                      name=resource_info['name'],
                      file=resource_info['file'])
        
        # Add nodes for data sources
        for data_name, data_info in data['data_sources'].items():
            G.add_node(data_name,
                      type='data',
                      resource_type=data_info['type'],
                      name=data_info['name'],
                      file=data_info['file'])
        
        # Add nodes for modules
        for module_name, module_info in data['modules'].items():
            G.add_node(module_name,
                      type='module',
                      name=module_name,
                      file=module_info['file'])
        
        # Add edges for dependencies
        for resource_name, resource_info in data['resources'].items():
            for dep in resource_info['dependencies']:
                if dep in G.nodes:
                    G.add_edge(dep, resource_name)
        
        for data_name, data_info in data['data_sources'].items():
            for dep in data_info['dependencies']:
                if dep in G.nodes:
                    G.add_edge(dep, data_name)
        
        for module_name, module_info in data['modules'].items():
            for dep in module_info['dependencies']:
                if dep in G.nodes:
                    G.add_edge(dep, module_name)
        
        return G
    
    def export_html(self, graph: nx.DiGraph, output_path: str) -> str:
        """Export interactive HTML visualization."""
        # Convert graph to JSON for d3.js
        graph_data = self._graph_to_json(graph)
        
        # Create output directory
        output_dir = Path(output_path)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy static files
        static_dir = Path(__file__).parent / 'static'
        if static_dir.exists():
            import shutil
            shutil.copytree(static_dir, output_dir / 'static', dirs_exist_ok=True)
        
        # Render HTML template
        template_path = Path(__file__).parent / 'templates'
        if not template_path.exists():
            template_path.mkdir(parents=True)
        
        html_content = self._generate_html_template(graph_data)
        
        output_file = output_dir / 'index.html'
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        return str(output_file)
    
    def export_svg(self, graph: nx.DiGraph, output_path: str) -> str:
        """Export SVG visualization using Graphviz."""
        dot = graphviz.Digraph(comment='Terraform Dependency Graph')
        dot.attr(rankdir='TB')
        
        # Add nodes
        for node, attrs in graph.nodes(data=True):
            node_type = attrs.get('type', 'resource')
            color = self._get_node_color(node_type)
            shape = self._get_node_shape(node_type)
            
            dot.node(node, attrs.get('name', node), 
                    color=color, shape=shape, style='filled')
        
        # Add edges
        for edge in graph.edges():
            dot.edge(edge[0], edge[1])
        
        # Generate SVG
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        dot.render(str(output_file.with_suffix('')), format='svg', cleanup=True)
        return str(output_file.with_suffix('.svg'))
    
    def export_png(self, graph: nx.DiGraph, output_path: str) -> str:
        """Export PNG visualization using Graphviz."""
        dot = graphviz.Digraph(comment='Terraform Dependency Graph')
        dot.attr(rankdir='TB')
        
        # Add nodes
        for node, attrs in graph.nodes(data=True):
            node_type = attrs.get('type', 'resource')
            color = self._get_node_color(node_type)
            shape = self._get_node_shape(node_type)
            
            dot.node(node, attrs.get('name', node), 
                    color=color, shape=shape, style='filled')
        
        # Add edges
        for edge in graph.edges():
            dot.edge(edge[0], edge[1])
        
        # Generate PNG
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        dot.render(str(output_file.with_suffix('')), format='png', cleanup=True)
        return str(output_file.with_suffix('.png'))
    
    def export_json(self, graph: nx.DiGraph, output_path: str) -> str:
        """Export graph data as JSON."""
        graph_data = self._graph_to_json(graph)
        
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(graph_data, f, indent=2)
        
        return str(output_file)
    
    def _graph_to_json(self, graph: nx.DiGraph) -> Dict[str, Any]:
        """Convert NetworkX graph to JSON format for d3.js."""
        nodes = []
        for node, attrs in graph.nodes(data=True):
            nodes.append({
                'id': node,
                'name': attrs.get('name', node),
                'type': attrs.get('type', 'resource'),
                'resource_type': attrs.get('resource_type', ''),
                'file': attrs.get('file', ''),
                'group': self._get_node_group(attrs.get('type', 'resource'))
            })
        
        links = []
        for edge in graph.edges():
            links.append({
                'source': edge[0],
                'target': edge[1],
                'value': 1
            })
        
        return {
            'nodes': nodes,
            'links': links
        }
    
    def _get_node_color(self, node_type: str) -> str:
        """Get color for node type."""
        colors = {
            'resource': '#4CAF50',
            'data': '#2196F3',
            'module': '#FF9800'
        }
        return colors.get(node_type, '#9E9E9E')
    
    def _get_node_shape(self, node_type: str) -> str:
        """Get shape for node type."""
        shapes = {
            'resource': 'box',
            'data': 'ellipse',
            'module': 'diamond'
        }
        return shapes.get(node_type, 'box')
    
    def _get_node_group(self, node_type: str) -> int:
        """Get group for node type (for d3.js coloring)."""
        groups = {
            'resource': 1,
            'data': 2,
            'module': 3
        }
        return groups.get(node_type, 0)
    
    def _generate_html_template(self, graph_data: Dict[str, Any]) -> str:
        """Generate HTML template with embedded d3.js visualization."""
        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Dependency Graph - Blast Radius</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
        }}
        .controls {{
            padding: 20px;
            border-bottom: 1px solid #eee;
            display: flex;
            gap: 20px;
            align-items: center;
            flex-wrap: wrap;
        }}
        .search-box {{
            flex: 1;
            min-width: 200px;
        }}
        .search-box input {{
            width: 100%;
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }}
        .filter-buttons {{
            display: flex;
            gap: 10px;
        }}
        .filter-btn {{
            padding: 8px 16px;
            border: 1px solid #ddd;
            background: white;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        }}
        .filter-btn.active {{
            background: #667eea;
            color: white;
            border-color: #667eea;
        }}
        .graph-container {{
            height: 600px;
            position: relative;
        }}
        .node {{
            cursor: pointer;
        }}
        .node:hover {{
            stroke: #333;
            stroke-width: 2px;
        }}
        .link {{
            stroke: #999;
            stroke-opacity: 0.6;
        }}
        .tooltip {{
            position: absolute;
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            pointer-events: none;
            z-index: 1000;
        }}
        .legend {{
            padding: 20px;
            border-top: 1px solid #eee;
        }}
        .legend-item {{
            display: inline-block;
            margin-right: 20px;
            font-size: 14px;
        }}
        .legend-color {{
            display: inline-block;
            width: 16px;
            height: 16px;
            margin-right: 8px;
            border-radius: 2px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Terraform Dependency Graph</h1>
            <p>Interactive visualization of your infrastructure dependencies</p>
        </div>
        
        <div class="controls">
            <div class="search-box">
                <input type="text" id="search" placeholder="Search resources...">
            </div>
            <div class="filter-buttons">
                <button class="filter-btn active" data-type="all">All</button>
                <button class="filter-btn" data-type="resource">Resources</button>
                <button class="filter-btn" data-type="data">Data Sources</button>
                <button class="filter-btn" data-type="module">Modules</button>
            </div>
        </div>
        
        <div class="graph-container" id="graph"></div>
        
        <div class="legend">
            <div class="legend-item">
                <span class="legend-color" style="background: #4CAF50;"></span>
                Resources
            </div>
            <div class="legend-item">
                <span class="legend-color" style="background: #2196F3;"></span>
                Data Sources
            </div>
            <div class="legend-item">
                <span class="legend-color" style="background: #FF9800;"></span>
                Modules
            </div>
        </div>
    </div>

    <script>
        // Graph data
        const graphData = {json.dumps(graph_data)};
        
        // Setup
        const width = document.getElementById('graph').clientWidth;
        const height = 600;
        
        const svg = d3.select('#graph')
            .append('svg')
            .attr('width', width)
            .attr('height', height);
        
        const g = svg.append('g');
        
        // Add zoom behavior
        const zoom = d3.zoom()
            .on('zoom', (event) => {{
                g.attr('transform', event.transform);
            }});
        
        svg.call(zoom);
        
        // Create force simulation
        const simulation = d3.forceSimulation(graphData.nodes)
            .force('link', d3.forceLink(graphData.links).id(d => d.id).distance(100))
            .force('charge', d3.forceManyBody().strength(-300))
            .force('center', d3.forceCenter(width / 2, height / 2))
            .force('collision', d3.forceCollide().radius(30));
        
        // Create links
        const link = g.append('g')
            .selectAll('line')
            .data(graphData.links)
            .enter().append('line')
            .attr('class', 'link')
            .attr('stroke-width', 2);
        
        // Create nodes
        const node = g.append('g')
            .selectAll('circle')
            .data(graphData.nodes)
            .enter().append('circle')
            .attr('class', 'node')
            .attr('r', 8)
            .attr('fill', d => {{
                const colors = ['#9E9E9E', '#4CAF50', '#2196F3', '#FF9800'];
                return colors[d.group] || colors[0];
            }})
            .call(d3.drag()
                .on('start', dragstarted)
                .on('drag', dragged)
                .on('end', dragended));
        
        // Add tooltips
        const tooltip = d3.select('body').append('div')
            .attr('class', 'tooltip')
            .style('opacity', 0);
        
        node.on('mouseover', function(event, d) {{
            tooltip.transition()
                .duration(200)
                .style('opacity', .9);
            tooltip.html(`
                <strong>${{d.name}}</strong><br/>
                Type: ${{d.type}}<br/>
                ${{d.resource_type ? 'Resource: ' + d.resource_type + '<br/>' : ''}}
                File: ${{d.file}}
            `)
                .style('left', (event.pageX + 10) + 'px')
                .style('top', (event.pageY - 28) + 'px');
        }})
        .on('mouseout', function(d) {{
            tooltip.transition()
                .duration(500)
                .style('opacity', 0);
        }});
        
        // Update positions
        simulation.on('tick', () => {{
            link
                .attr('x1', d => d.source.x)
                .attr('y1', d => d.source.y)
                .attr('x2', d => d.target.x)
                .attr('y2', d => d.target.y);
            
            node
                .attr('cx', d => d.x)
                .attr('cy', d => d.y);
        }});
        
        // Drag functions
        function dragstarted(event, d) {{
            if (!event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }}
        
        function dragged(event, d) {{
            d.fx = event.x;
            d.fy = event.y;
        }}
        
        function dragended(event, d) {{
            if (!event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }}
        
        // Search functionality
        document.getElementById('search').addEventListener('input', function(e) {{
            const searchTerm = e.target.value.toLowerCase();
            node.style('opacity', d => {{
                return d.name.toLowerCase().includes(searchTerm) || 
                       d.type.toLowerCase().includes(searchTerm) ? 1 : 0.1;
            }});
        }});
        
        // Filter functionality
        document.querySelectorAll('.filter-btn').forEach(btn => {{
            btn.addEventListener('click', function() {{
                const filterType = this.dataset.type;
                
                // Update active button
                document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                this.classList.add('active');
                
                // Filter nodes
                node.style('opacity', d => {{
                    return filterType === 'all' || d.type === filterType ? 1 : 0.1;
                }});
            }});
        }});
    </script>
</body>
</html>
"""
    
    def serve(self, path: str, host: str = '127.0.0.1', port: int = 5000):
        """Start web server for interactive visualization."""
        print(f"Parsing Terraform configuration from: {path}")
        
        # Parse Terraform
        data = self.parse_terraform(path)
        self.terraform_path = path
        
        # Generate graph
        graph = self.generate_graph(data)
        self.graph_data = self._graph_to_json(graph)
        
        print(f"Generated graph with {len(graph.nodes)} nodes and {len(graph.edges)} edges")
        print(f"Starting web server at http://{host}:{port}")
        
        # Setup Flask routes
        @self.app.route('/')
        def index():
            return render_template('index.html', graph_data=self.graph_data)
        
        @self.app.route('/api/graph')
        def api_graph():
            return jsonify(self.graph_data)
        
        @self.app.route('/static/<path:filename>')
        def static_files(filename):
            static_dir = Path(__file__).parent / 'static'
            return send_from_directory(static_dir, filename)
        
        # Start server
        self.app.run(host=host, port=port, debug=False)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Custom Blast Radius - Terraform Dependency Visualizer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python blast_radius.py --serve examples/aws-vpc
  python blast_radius.py --export examples/multi-tier-app --format html
  python blast_radius.py --export examples/kubernetes --format all --output diagrams/
        """
    )
    
    parser.add_argument('path', help='Path to Terraform configuration directory')
    parser.add_argument('--serve', action='store_true', help='Start web server')
    parser.add_argument('--export', action='store_true', help='Export static files')
    parser.add_argument('--format', choices=['html', 'svg', 'png', 'json', 'all'], 
                       default='html', help='Output format')
    parser.add_argument('--output', default='output', help='Output directory')
    parser.add_argument('--port', type=int, default=5000, help='Web server port')
    parser.add_argument('--host', default='127.0.0.1', help='Web server host')
    
    args = parser.parse_args()
    
    try:
        blast_radius = BlastRadius()
        
        if args.serve:
            blast_radius.serve(args.path, args.host, args.port)
        elif args.export:
            print(f"Parsing Terraform configuration from: {args.path}")
            data = blast_radius.parse_terraform(args.path)
            graph = blast_radius.generate_graph(data)
            
            if args.format == 'all':
                # Export all formats
                html_file = blast_radius.export_html(graph, f"{args.output}/index.html")
                svg_file = blast_radius.export_svg(graph, f"{args.output}/graph.svg")
                png_file = blast_radius.export_png(graph, f"{args.output}/graph.png")
                json_file = blast_radius.export_json(graph, f"{args.output}/graph.json")
                
                print(f"Exported all formats to {args.output}/")
                print(f"  HTML: {html_file}")
                print(f"  SVG: {svg_file}")
                print(f"  PNG: {png_file}")
                print(f"  JSON: {json_file}")
            else:
                # Export single format
                if args.format == 'html':
                    output_file = blast_radius.export_html(graph, f"{args.output}/index.html")
                elif args.format == 'svg':
                    output_file = blast_radius.export_svg(graph, f"{args.output}/graph.svg")
                elif args.format == 'png':
                    output_file = blast_radius.export_png(graph, f"{args.output}/graph.png")
                elif args.format == 'json':
                    output_file = blast_radius.export_json(graph, f"{args.output}/graph.json")
                
                print(f"Exported {args.format.upper()} to: {output_file}")
        else:
            parser.print_help()
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main() 