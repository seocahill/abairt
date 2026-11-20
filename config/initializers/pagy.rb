# Pagy 43: out-of-range pages render empty (no RangeError) rather than raising.
Pagy::OPTIONS[:raise_range_error] = false
