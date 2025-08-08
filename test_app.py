#!/usr/bin/env python3
"""
Simple test script for Blast Radius application
"""

import sys
import os
from pathlib import Path

def test_import():
    """Test that the application can be imported"""
    try:
        from blast_radius import BlastRadius
        print("✅ Successfully imported BlastRadius class")
        return True
    except ImportError as e:
        print(f"❌ Failed to import BlastRadius: {e}")
        return False

def test_basic_functionality():
    """Test basic functionality"""
    try:
        from blast_radius import BlastRadius
        
        # Create instance
        app = BlastRadius()
        print("✅ Successfully created BlastRadius instance")
        
        # Test node color function
        color = app._get_node_color("resource")
        assert color == "#4CAF50"
        print("✅ Node color function works")
        
        # Test node shape function
        shape = app._get_node_shape("resource")
        assert shape == "box"
        print("✅ Node shape function works")
        
        return True
    except Exception as e:
        print(f"❌ Basic functionality test failed: {e}")
        return False

def test_terraform_parsing():
    """Test Terraform parsing with a simple example"""
    try:
        from blast_radius import BlastRadius
        import tempfile
        
        app = BlastRadius()
        
        # Create a temporary Terraform file
        with tempfile.TemporaryDirectory() as temp_dir:
            tf_file = Path(temp_dir) / "main.tf"
            tf_content = '''
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test-vpc"
  }
}
'''
            tf_file.write_text(tf_content)
            
            # Parse the Terraform configuration
            result = app.parse_terraform(temp_dir)
            
            # Verify the result
            assert "resources" in result
            assert "aws_vpc.main" in result["resources"]
            print("✅ Terraform parsing works")
            
        return True
    except Exception as e:
        print(f"❌ Terraform parsing test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 Testing Custom Blast Radius Application")
    print("=" * 50)
    
    tests = [
        ("Import Test", test_import),
        ("Basic Functionality", test_basic_functionality),
        ("Terraform Parsing", test_terraform_parsing),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 Running {test_name}...")
        if test_func():
            passed += 1
        else:
            print(f"❌ {test_name} failed")
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The application is working correctly.")
        return 0
    else:
        print("⚠️  Some tests failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 