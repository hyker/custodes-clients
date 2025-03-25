#!/usr/bin/env python3

import ast
import base64
import sys

def convert_string_int_array_to_bytes_and_base64(string_array):
    try:
        int_array = ast.literal_eval(string_array)
        if not all(0 <= x <= 255 for x in int_array):
            raise ValueError("All integers must be in the range 0-255")
        # Convert integer array to bytes
        byte_data = bytes(int_array)
        base64_encoded = base64.b64encode(byte_data).decode('utf-8')
        return base64_encoded
    except (SyntaxError, ValueError) as e:
        raise ValueError(f"Invalid input: {e}")


input = sys.argv[1]
print(convert_string_int_array_to_bytes_and_base64(input))

