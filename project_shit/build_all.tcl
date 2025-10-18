# Vivado TCL Script - Synthesize, Implement, and Generate Bitstream

puts "=========================================="
puts "Starting Full Build Process"
puts "=========================================="

# Open project
open_project C:/Users/xiang/ee2026_Project/project_shit/project_shit.xpr

puts "\n=========================================="
puts "Step 1: Running Synthesis"
puts "=========================================="

# Reset synthesis run
reset_run synth_1

# Launch synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

puts "\nSynthesis Status: $synth_status"
puts "Synthesis Progress: $synth_progress"

if {$synth_status != "synth_design Complete!"} {
    puts "\nERROR: Synthesis failed!"
    puts "Check the synthesis log for errors."
    exit 1
}

puts "\n✓ Synthesis completed successfully!"

puts "\n=========================================="
puts "Step 2: Running Implementation"
puts "=========================================="

# Launch implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]

puts "\nImplementation Status: $impl_status"
puts "Implementation Progress: $impl_progress"

if {$impl_status != "route_design Complete!"} {
    puts "\nERROR: Implementation failed!"
    puts "Check the implementation log for errors."
    exit 1
}

puts "\n✓ Implementation completed successfully!"

puts "\n=========================================="
puts "Step 3: Generating Bitstream"
puts "=========================================="

# Launch bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check bitstream status
set bitstream_status [get_property STATUS [get_runs impl_1]]

puts "\nBitstream Status: $bitstream_status"

if {$bitstream_status != "write_bitstream Complete!"} {
    puts "\nERROR: Bitstream generation failed!"
    exit 1
}

puts "\n✓ Bitstream generated successfully!"

puts "\n=========================================="
puts "Build Summary"
puts "=========================================="
puts "Synthesis:      PASSED ✓"
puts "Implementation: PASSED ✓"
puts "Bitstream:      PASSED ✓"
puts ""
puts "Bitstream location:"
puts "  C:/Users/xiang/ee2026_Project/project_shit/project_shit.runs/impl_1/Top_Student.bit"
puts ""
puts "=========================================="
puts "Ready to Program FPGA!"
puts "=========================================="

exit 0
