#!/usr/bin/env python3

"""
File: bin2hex.py

Purpose
-------
This script converts a raw binary firmware file (.bin) into a text-based
hexadecimal file where each line represents a 32-bit word.

This format is commonly used in hardware design and simulation workflows.
For example, in Verilog/SystemVerilog, the `$readmemh` system task loads
memory contents from a hex text file into a ROM or RAM during simulation.

Typical flow in FPGA/SoC development:
    1. Compile firmware → firmware.bin
    2. Convert binary → rom.hex (using this script)
    3. Load rom.hex into a Verilog ROM using $readmemh

Example usage:
    python3 bin2hex.py firmware.bin rom.hex

Output format:
    Each line contains one 32-bit word written in lowercase hexadecimal
    without the "0x" prefix.

Example line in output file:
    00000013

Important detail:
    The data is interpreted as little-endian 32-bit words, which matches
    the memory layout used by architectures like RISC-V.
"""
# -----------------------------------------------------------------------------
# Standard Library Imports
# -----------------------------------------------------------------------------

import sys
# sys module provides access to command-line arguments and system utilities.
# It is used here to read the input/output file paths passed by the user.

import struct
# struct module allows conversion between raw binary data (bytes) and
# Python values using C-style data layouts.
# Here it is used to interpret the binary file as a sequence of 32-bit integers.


# -----------------------------------------------------------------------------
# Function: bin2hex
# -----------------------------------------------------------------------------
def bin2hex(input_path: str, output_path: str) -> None:
    """
    Convert a binary file into a hex file containing 32-bit words.

    Parameters
    ----------
    input_path : str
        Path to the input binary firmware file.

    output_path : str
        Path where the output hex file will be written.

    Operation
    ---------
    1. Read the entire binary file.
    2. Ensure the data size is aligned to a 4-byte boundary.
    3. Interpret the binary data as 32-bit little-endian integers.
    4. Write each word to the output file in hexadecimal format.

    This format is directly compatible with Verilog `$readmemh`.
    """

    # -------------------------------------------------------------------------
    # Read the entire binary file
    # -------------------------------------------------------------------------
    # "rb" mode opens the file in binary read mode.
    # This ensures that the data is read exactly as raw bytes without
    # any encoding or newline transformations.
    with open(input_path, "rb") as f:
        data = f.read()  # Read the entire binary file into memory

    # -------------------------------------------------------------------------
    # Ensure data size is aligned to 4 bytes (32-bit boundary)
    # -------------------------------------------------------------------------
    # Since we are converting the binary into 32-bit words (4 bytes each),
    # the total length must be divisible by 4.
    #
    # If the firmware size is not aligned (for example 10 bytes),
    # we pad the remaining bytes with zeros so that unpacking works safely.
    remainder = len(data) % 4

    if remainder:
        # Add zero bytes until the data length becomes a multiple of 4.
        # This is common in firmware images because instruction/data
        # memories are typically word-aligned.
        data += b'\x00' * (4 - remainder)

    # -------------------------------------------------------------------------
    # Convert raw bytes into 32-bit unsigned integers
    # -------------------------------------------------------------------------
    # struct.unpack converts a byte buffer into Python values.
    #
    # Format string explanation:
    #   "<"  = little-endian byte order
    #   I    = unsigned 32-bit integer
    #
    # Example:
    #   If data length = 16 bytes → format becomes "<4I"
    #   which means "read four little-endian unsigned 32-bit integers".
    #
    # Little-endian is used because many embedded CPUs (including RISC-V)
    # store the least significant byte first in memory.
    words = struct.unpack(f"<{len(data)//4}I", data)

    # -------------------------------------------------------------------------
    # Write the converted words into the hex output file
    # -------------------------------------------------------------------------
    # The output file will contain one 32-bit word per line.
    # This format is directly readable by Verilog's `$readmemh`.
    with open(output_path, "w") as f:

        # Iterate through each unpacked 32-bit word
        for word in words:

            # Format explanation:
            #   {word:08x}
            #
            #   08  → always print 8 characters (32-bit hex width)
            #   x   → lowercase hexadecimal
            #
            # Example:
            #   word = 19  → 00000013
            f.write(f"{word:08x}\n")

    # -------------------------------------------------------------------------
    # Print a summary message for the user
    # -------------------------------------------------------------------------
    # This confirms successful conversion and shows:
    #   • number of 32-bit words written
    #   • total byte size
    #   • output file path
    print(f"Converted {len(words)} words ({len(data)} bytes) → {output_path}")


# -----------------------------------------------------------------------------
# Program Entry Point
# -----------------------------------------------------------------------------
# This block ensures that the script executes only when run directly
# from the command line. If this file is imported as a module, this
# section will not run.
if __name__ == "__main__":

    # -------------------------------------------------------------------------
    # Validate command-line arguments
    # -------------------------------------------------------------------------
    # Expected usage:
    #   python3 bin2hex.py <input.bin> <output.hex>
    #
    # sys.argv contents:
    #   argv[0] → script name
    #   argv[1] → input file
    #   argv[2] → output file
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.hex>")
        sys.exit(1)  # Exit with error status

    # -------------------------------------------------------------------------
    # Call the conversion function with user-provided paths
    # -------------------------------------------------------------------------
    bin2hex(sys.argv[1], sys.argv[2])
