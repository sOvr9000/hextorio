-- DEPRECATED: Legacy snapshot of `main` trade-shape presets for temporary sampling/comparison.
-- Intended to be deleted after legacy sampling is complete.
return {
    ["simple"] = {
        {num_inputs = 1, num_outputs = 1, weight = 447},
        {num_inputs = 1, num_outputs = 2, weight = 93},
        {num_inputs = 1, num_outputs = 3, weight = 36},
        {num_inputs = 2, num_outputs = 1, weight = 93},
        {num_inputs = 2, num_outputs = 2, weight = 71},
        {num_inputs = 2, num_outputs = 3, weight = 60},
        {num_inputs = 3, num_outputs = 1, weight = 36},
        {num_inputs = 3, num_outputs = 2, weight = 60},
        {num_inputs = 3, num_outputs = 3, weight = 106},
    },
    ["balanced"] = {
        {num_inputs = 1, num_outputs = 1, weight = 247},
        {num_inputs = 1, num_outputs = 2, weight = 102},
        {num_inputs = 1, num_outputs = 3, weight = 48},
        {num_inputs = 2, num_outputs = 1, weight = 102},
        {num_inputs = 2, num_outputs = 2, weight = 95},
        {num_inputs = 2, num_outputs = 3, weight = 91},
        {num_inputs = 3, num_outputs = 1, weight = 48},
        {num_inputs = 3, num_outputs = 2, weight = 91},
        {num_inputs = 3, num_outputs = 3, weight = 176},
    },
    ["complex"] = {
        {num_inputs = 1, num_outputs = 1, weight = 117},
        {num_inputs = 1, num_outputs = 2, weight = 89},
        {num_inputs = 1, num_outputs = 3, weight = 53},
        {num_inputs = 2, num_outputs = 1, weight = 89},
        {num_inputs = 2, num_outputs = 2, weight = 106},
        {num_inputs = 2, num_outputs = 3, weight = 118},
        {num_inputs = 3, num_outputs = 1, weight = 53},
        {num_inputs = 3, num_outputs = 2, weight = 118},
        {num_inputs = 3, num_outputs = 3, weight = 257},
    },
}
