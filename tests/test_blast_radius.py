#!/usr/bin/env python3
"""
Tests for Custom Blast Radius application
"""

import pytest
import tempfile
import os
from pathlib import Path
from blast_radius import BlastRadius


class TestBlastRadius:
    """Test cases for BlastRadius class"""

    def setup_method(self):
        """Set up test fixtures"""
        self.blast_radius = BlastRadius()

    def test_parse_terraform_empty_directory(self):
        """Test parsing empty directory"""
        with tempfile.TemporaryDirectory() as temp_dir:
            with pytest.raises(ValueError, match="No Terraform files found"):
                self.blast_radius.parse_terraform(temp_dir)

    def test_parse_terraform_nonexistent_directory(self):
        """Test parsing nonexistent directory"""
        with pytest.raises(FileNotFoundError):
            self.blast_radius.parse_terraform("/nonexistent/path")

    def test_parse_terraform_valid_files(self):
        """Test parsing valid Terraform files"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create a simple Terraform file
            tf_file = Path(temp_dir) / "main.tf"
            tf_content = '''
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "test-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  
  tags = {
    Name = "test-subnet"
  }
}
'''
            tf_file.write_text(tf_content)

            # Parse the Terraform configuration
            result = self.blast_radius.parse_terraform(temp_dir)

            # Verify the result
            assert "resources" in result
            assert "aws_vpc.main" in result["resources"]
            assert "aws_subnet.main" in result["resources"]
            assert result["resources"]["aws_subnet.main"]["dependencies"] == ["aws_vpc.main"]

    def test_generate_graph(self):
        """Test graph generation"""
        # Create test data
        data = {
            "resources": {
                "aws_vpc.main": {
                    "type": "aws_vpc",
                    "name": "main",
                    "file": "main.tf",
                    "dependencies": []
                },
                "aws_subnet.main": {
                    "type": "aws_subnet",
                    "name": "main",
                    "file": "main.tf",
                    "dependencies": ["aws_vpc.main"]
                }
            },
            "data_sources": {},
            "modules": {},
            "path": "/test"
        }

        # Generate graph
        graph = self.blast_radius.generate_graph(data)

        # Verify graph structure
        assert len(graph.nodes) == 2
        assert len(graph.edges) == 1
        assert "aws_vpc.main" in graph.nodes
        assert "aws_subnet.main" in graph.nodes
        assert ("aws_vpc.main", "aws_subnet.main") in graph.edges

    def test_export_json(self):
        """Test JSON export"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create test data
            data = {
                "resources": {
                    "aws_vpc.main": {
                        "type": "aws_vpc",
                        "name": "main",
                        "file": "main.tf",
                        "dependencies": []
                    }
                },
                "data_sources": {},
                "modules": {},
                "path": "/test"
            }

            # Generate graph
            graph = self.blast_radius.generate_graph(data)

            # Export JSON
            output_file = os.path.join(temp_dir, "test.json")
            result = self.blast_radius.export_json(graph, output_file)

            # Verify file was created
            assert os.path.exists(result)
            assert result.endswith(".json")

    def test_get_node_color(self):
        """Test node color assignment"""
        assert self.blast_radius._get_node_color("resource") == "#4CAF50"
        assert self.blast_radius._get_node_color("data") == "#2196F3"
        assert self.blast_radius._get_node_color("module") == "#FF9800"
        assert self.blast_radius._get_node_color("unknown") == "#9E9E9E"

    def test_get_node_shape(self):
        """Test node shape assignment"""
        assert self.blast_radius._get_node_shape("resource") == "box"
        assert self.blast_radius._get_node_shape("data") == "ellipse"
        assert self.blast_radius._get_node_shape("module") == "diamond"
        assert self.blast_radius._get_node_shape("unknown") == "box"

    def test_get_node_group(self):
        """Test node group assignment"""
        assert self.blast_radius._get_node_group("resource") == 1
        assert self.blast_radius._get_node_group("data") == 2
        assert self.blast_radius._get_node_group("module") == 3
        assert self.blast_radius._get_node_group("unknown") == 0


def test_main_import():
    """Test that the main module can be imported"""
    import blast_radius
    assert hasattr(blast_radius, 'BlastRadius')


if __name__ == "__main__":
    pytest.main([__file__]) 