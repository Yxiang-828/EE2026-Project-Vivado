# Vivado TCL Script - Run Full VGA Text Display Simulation

puts "=========================================="
puts "Full VGA Text Display Simulation"
puts "=========================================="

# Open project
open_project C:/Users/xiang/ee2026_Project/project_shit/project_shit.xpr

# Add simulation sources
set sim_fileset [get_filesets sim_1]
set tb_file "C:/Users/xiang/ee2026_Project/project_shit/project_shit.srcs/sim_1/new/tb_calc_mode_text_display.v"
if {[file exists $tb_file]} {
    add_files -fileset $sim_fileset -norecurse $tb_file -quiet
}

# Add source files needed
add_files -norecurse "C:/Users/xiang/ee2026_Project/project_vivado/features/parser/data_parser_accumulator.v" -quiet
add_files -norecurse "C:/Users/xiang/ee2026_Project/project_vivado/Submodules/calc_mode_module.v" -quiet

# Update compile order
update_compile_order -fileset sources_1 -quiet
update_compile_order -fileset sim_1 -quiet

# Set top module
set_property top tb_calc_mode_text_display [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "Launching full VGA simulation..."
launch_simulation -mode behavioral

puts "Running for 2us (covers all test cases)..."
run 2us

puts "=========================================="
puts "Simulation Complete - Check results above"
puts "=========================================="

close_sim
exit
