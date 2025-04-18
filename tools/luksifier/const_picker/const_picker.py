import argparse
import base64
from mpmath import mp, sqrt, cbrt, pi, e, phi, zeta, ln2, ln10, catalan, euler, mpf


def parse_fractional_part(part: str, base: int) -> float:
    value = 0.0
    for i, digit in enumerate(part):
        value += int(digit, base) / (base ** (i + 1))
    return value

def parse_prefixed_number(s: str) -> float:
    s = s.strip().lower()

    if s.startswith("0x"):
        base = 16
        s = s[2:]
    elif s.startswith("0o"):
        base = 8
        s = s[2:]
    elif s.startswith("0b"):
        base = 2
        s = s[2:]
    else:
        base = 10

    if '.' in s:
        int_part, frac_part = s.split('.')
    else:
        int_part, frac_part = s, ''

    int_val = int(int_part, base) if int_part else 0
    frac_val = parse_fractional_part(frac_part, base) if frac_part else 0

    return int_val + frac_val


def get_constant(name, n=None):
    if name == "pi":
        return pi
    elif name == "e":
        return e
    elif name == "phi":
        return phi
    elif name == "ln2":
        return ln2
    elif name == "ln10":
        return ln10
    elif name == "sqrt":
        return sqrt(n)
    elif name == "cube":
        return cbrt(n)
    elif name == "zeta":
        return zeta(n)
    elif name == "catalan":
        return catalan
    elif name == "euler":
        return euler
    else:
        raise ValueError(f"Unknown constant type: {name}")

def encode_block(block: str, fmt: str) -> str:
    if fmt == "raw":
        return block
    elif fmt == "hex":
        return block.encode("utf-8").hex()
    elif fmt == "base64":
        return base64.b64encode(block.encode("utf-8")).decode("utf-8")
    else:
        raise ValueError(f"Unsupported format: {fmt}")

def main():
    parser = argparse.ArgumentParser(description="Extract digits from mathematical constants")
    parser.add_argument("-c","--const", required=True,help="Constant: pi, e, phi, sqrt, cube, zeta, ln2, ln10, catalan, euler")
    parser.add_argument(
        "-n","--n",
        help="Used for sqrt(n), cube(n), zeta(n) (supports 0x/0o/0b prefixes, defaults to decimal)")
    parser.add_argument(
        "-s", "--start",
        required=True,
        help="Start digit offset (supports 0x/0o/0b prefixes, defaults to decimal)"
    )
    parser.add_argument(
        "-l", "--length",
        required=True,
        help="Digits per block (supports 0x/0o/0b prefixes, defaults to decimal)"
    )
    parser.add_argument("-C","--count", default="1", help="Number of blocks (in given base)")
    parser.add_argument("-f","--format", choices=["raw", "hex", "base64"], default="raw", help="Output format")
    parser.add_argument("-d","--dry-run", action="store_true", help="Only show how many digits will be needed, then exit")
    parser.add_argument("-v","--verbose", action="store_true", help="Show detailed processing logs")
    parser.add_argument("-o","--out", action="store_true", help="Write output to a file")

    args = parser.parse_args()

    start = int(args.start, 0)
    length = int(args.length, 0)
    count = int(args.count, 0)
    n_val = parse_prefixed_number(args.n) if args.n else None

    total_digits = start + length * count + 10

    if args.dry_run:
        print(f"[Dry Run] Total digits needed for computation: {total_digits}")
        return

    if args.verbose:
        print(f"[Verbose] start={start}, length={length}, count={count}")
        print(f"[Verbose] Computing {args.const} with precision: {total_digits} digits")

    mp.dps = total_digits
    const_val = get_constant(args.const, n_val)
    # digits_str = str(const_val)
    digits_str = str(const_val).split(".")[1] # Remove the integer part (i.e., everything before the decimal point)

    for i in range(count):
        offset = start + i * length
        raw_block = digits_str[offset:offset + length]
        formatted = encode_block(raw_block, args.format)

        message = f"[{i}] {args.const} at offset {offset} (0x{offset:X}), length {length} (0x{length:X})\n"
        if args.verbose:
            print(message)
        print(formatted)
        if args.out:
            n_suffix = f"_n{args.n}" if args.n is not None else ""
            filename = f"{args.const}{n_suffix}_{args.start}_{args.length}_{i}.mconst"
            with open(filename, "w", encoding="utf-8") as f:
                f.write(formatted)
            if args.verbose:
                print(f"[Verbose] Output written to {filename}")

if __name__ == "__main__":
    main()
