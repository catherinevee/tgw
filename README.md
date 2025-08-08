# Custom Blast Radius

Interactive visualizations of Terraform dependency graphs using d3.js

## Overview

This is a custom implementation of [Blast Radius](https://github.com/28mm/blast-radius) for creating interactive visualizations of Terraform dependency graphs. The application provides:

- **Interactive Visualizations**: Zoom, pan, search, and filter dependency graphs
- **Multiple Output Formats**: HTML, SVG, PNG, and JSON
- **Terraform Examples**: Real-world Terraform configurations with valid HCL syntax
- **Web Interface**: Modern, responsive web interface
- **Docker Support**: Containerized deployment

## Features

- 🎯 **Interactive Dependency Graphs**: Visualize Terraform resource relationships
- 🔍 **Search & Filter**: Find specific resources and filter by type
- 📊 **Multiple Formats**: Export as HTML, SVG, PNG, or JSON
- 🐳 **Docker Support**: Run without local dependencies
- 🌐 **Web Interface**: Modern, responsive UI
- 📝 **Real Examples**: Working Terraform configurations included

## Prerequisites

- **Python 3.7+**
- **Graphviz** (for graph layout)
- **Docker** (optional, for containerized deployment)

### Installing Graphviz

**macOS:**
```bash
brew install graphviz
```

**Ubuntu/Debian:**
```bash
sudo apt-get install graphviz
```

**Windows:**
Download from [Graphviz website](https://graphviz.org/download/)

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Run with Examples

```bash
# Generate interactive visualization
python blast_radius.py --serve examples/aws-vpc

# Export static files
python blast_radius.py --export examples/aws-vpc --output vpc-diagram
```

### 3. Docker (No Local Dependencies)

```bash
# Build and run
docker build -t custom-blast-radius .
docker run -p 5000:5000 -v $(pwd)/examples:/data custom-blast-radius --serve /data/aws-vpc
```

## Terraform Examples

The application includes several real-world Terraform examples:

### 1. AWS VPC with Subnets
**Location**: `examples/aws-vpc/`

A complete VPC setup with:
- VPC with CIDR block
- Public and private subnets across multiple AZs
- Internet Gateway
- NAT Gateway
- Route tables
- Security groups

### 2. Multi-Tier Application
**Location**: `examples/multi-tier-app/`

A three-tier application architecture:
- Load balancer tier
- Application tier (EC2 instances)
- Database tier (RDS)
- Auto Scaling groups
- CloudWatch monitoring

### 3. Kubernetes Infrastructure
**Location**: `examples/kubernetes/`

EKS cluster setup with:
- EKS cluster
- Node groups
- IAM roles and policies
- VPC CNI
- Load balancer controller

### 4. Serverless Architecture
**Location**: `examples/serverless/`

Serverless components:
- Lambda functions
- API Gateway
- DynamoDB tables
- S3 buckets
- CloudWatch events

## Usage

### Command Line Interface

```bash
# Basic usage
python blast_radius.py [OPTIONS] PATH

# Options
--serve          Start web server
--export         Export static files
--format FORMAT  Output format (html, svg, png, json)
--output PATH    Output directory
--port PORT      Web server port (default: 5000)
--host HOST      Web server host (default: 127.0.0.1)
```

### Examples

```bash
# Serve interactive visualization
python blast_radius.py --serve examples/aws-vpc

# Export HTML visualization
python blast_radius.py --export examples/multi-tier-app --format html

# Export all formats
python blast_radius.py --export examples/kubernetes --format all

# Custom port
python blast_radius.py --serve examples/serverless --port 8080
```

### Web Interface

Once the server is running, open your browser to `http://127.0.0.1:5000` to access the interactive visualization.

**Features:**
- **Zoom & Pan**: Mouse wheel to zoom, drag to pan
- **Search**: Type to search for resources
- **Filter**: Filter by resource type
- **Details**: Click resources for detailed information
- **Export**: Download as SVG or PNG

## Project Structure

```
blast-radius/
├── blast_radius.py          # Main application
├── requirements.txt         # Python dependencies
├── Dockerfile              # Docker configuration
├── docker-compose.yml      # Docker Compose setup
├── examples/               # Terraform examples
│   ├── aws-vpc/           # VPC example
│   ├── multi-tier-app/    # Multi-tier application
│   ├── kubernetes/        # EKS cluster
│   └── serverless/        # Serverless architecture
├── static/                # Web assets
│   ├── css/              # Stylesheets
│   ├── js/               # JavaScript
│   └── images/           # Images
├── templates/             # HTML templates
└── tests/                # Test files
```

## Development

### Running Tests

```bash
python -m pytest tests/
```

### Adding New Examples

1. Create a new directory in `examples/`
2. Add valid Terraform files (`.tf`)
3. Run `terraform init` in the example directory
4. Test with: `python blast_radius.py --serve examples/your-example`

### Customizing Styles

Modify files in `static/css/` and `static/js/` to customize the visualization appearance and behavior.

## API Reference

### blast_radius.py

Main application class with methods:

- `parse_terraform(path)`: Parse Terraform configuration
- `generate_graph(data)`: Generate dependency graph
- `export_html(graph, output_path)`: Export HTML visualization
- `export_svg(graph, output_path)`: Export SVG file
- `export_png(graph, output_path)`: Export PNG file
- `serve(path, host, port)`: Start web server

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your changes
4. Include tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

Based on the original [Blast Radius](https://github.com/28mm/blast-radius) project by 28mm.

## Support

For issues and questions:
- Create an issue on GitHub
- Check the documentation in the `docs/` directory
- Review the examples for usage patterns