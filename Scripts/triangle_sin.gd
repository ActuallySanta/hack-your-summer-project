class_name TriangleWave extends Node

## Samples a Triangle wave described using the parameters. 
## Note the wave is structured so '0 = 0', if you want '0 = wave_height' see 'sample_complement'
static func sample(t: float, wave_length: float = 1, wave_height: float = 1) -> float:
	var wl_factor = t/wave_length;
	return wave_height * abs(2 * (wl_factor - floor(0.5 + wl_factor)))

## Returns the complement of the given sample.
## The complement 'c' and the sum of the sample 's' are the wave_height at all points
static func sample_complement(t: float, wave_length: float = 1, wave_height: float = 1) -> float:
	var wl_factor = t/wave_length;
	return wave_height - wave_height * abs(2 * (wl_factor - floor(0.5 + wl_factor)))
