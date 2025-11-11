Based on the project manual, here is a detailed breakdown of the requirements for the group project, known as the **Interactive FPGA Design Project (I-FDP)**.

---

### Team & Project Foundation

* **Team Size:** You must form a team of 4 students. Depending on the class size, some teams of 3 may be permitted.
* **Hardware:** The project must be created using the **Basys3 development board** and the Pmod OLED display.
* **Team Responsibility:** It's a teamwork project, and all members of a group will be penalized for plagiarism or academic misconduct. Each member is responsible for their individual part and the overall team project.

---

### I-FDP Theme & Functionality (Weeks 8-11)

The main group project is the Interactive FDP (I-FDP), which is developed from weeks 8 to 11.

* **Default Theme:** The default project theme is an **FPGA Based Smart Graphical Calculator**.
* **Alternative Themes:** Teams can propose an alternative theme, but it must be a project with deep integration of components rather than many small, unrelated parts.
* **Compulsory Requirements:**
    * **Functionality:** If doing the calculator, it must be able to perform simple addition and subtraction of single-digit whole numbers (e.g., `8+5`).
    * **Robustness:** The system must not require reprogramming for each new calculation and should not crash often.
    * **User Interface:** The project must use the switches, LEDs, and OLED display on the Basys3 board.
    * **User Experience:** A user must be able to input values and see the results on the board with ease.
* **Possible Enhancements:** You are encouraged to add value with enhancements like multi-digit operations, multiplication/division, graphing, or other features that demonstrate your Verilog skills.

---

### Implementation & Integration

* **Single Bitstream:** All individual components of the I-FDP must be fully integrated and functional within **ONE single bitstream**. The basic tasks assessed in week 8 are not required in this final bitstream.
* **Individual Responsibilities:** Each team member must be assigned a specific component of the I-FDP to code. The group's success depends on how well these individual parts are integrated into a cohesive final project.

---

### Deliverables and Deadlines

The project has several key submission deadlines throughout the semester.

* **1. I-FDP Proposal Document**
    * **What:** A 1-2 page PDF describing your group's chosen theme, overall function, and a breakdown of each member's responsibilities and weekly timeline.
    * **Deadline:** **Monday, October 13th, 2025, 6:00 AM**.
    * **Submission:** Uploaded to the CANVAS folder named "Week 8 I-FDP Proposal Submission".

* **2. Final Project Archive (ITEM A)**
    * **What:** A single Vivado project archive (`.zip`, max 400 MB) containing your final, integrated I-FDP and the single bitstream.
    * **Deadline:** **Tuesday, November 4th, 2025, 6:00 AM**.

* **3. Final Report / User Guide (ITEM B)**
    * **What:** A two-sheet (4-page) PDF report.
        * **Sheet 1:** A user guide for your project, with descriptions, instructions, and clear color images. Each student's contribution must be clearly marked and color-coded according to the manual's specifications.
        * **Sheet 2:** A list of all references (including websites, GitHub, and AI tools used) and course feedback.
    * **Deadline:** **Thursday, November 6th, 2025, 6:00 AM**.
    * **Note:** You must also bring **two printed color copies** of this report to your final presentation.

* **4. Peer Feedback (ITEM C)**
    * **What:** A peer feedback form to be completed on CANVAS.
    * **Deadline:** **Tuesday, November 11th, 2025, 6:00 AM**.

---

### Assessment & Grading

Your group's work will be assessed through both individual and group components.

* **I-FDP Proposal:** 2% (Group).
* **I-FDP Implementation:**
    * **16% (Individual):** 8% for each student's specific component implementation.
    * **8% (Group):** Awarded for the successful integration of all components into the final bitstream.
* **Final Presentation & Q&A (Weeks 12-13):**
    * **8% (Individual):** Based on your execution, understanding of the project, and answers to questions from the grader.
* **Peer Feedback:** The final individual mark is also influenced by peer feedback.
* **Citation is Crucial:** You **must** document and cite any open-source code, AI tools, or chatbots used in your report. Failure to do so will result in full penalties for the project.


# Verilog Coding Standards for Vivado FPGA Projects

## General Rules
- Use `reg` for variables assigned in `always` blocks
- Use `wire` for combinational logic and module connections
- Never declare `wire` inside `always` blocks
- Use meaningful signal names with consistent prefixes
- Comment all modules, ports, and complex logic

## Module Structure
- One module per file
- File name matches module name
- Use `timescale 1ns / 1ps` at top of each file
- Declare parameters before ports
- Group related ports together

## Always Blocks
- Use `@(posedge clk)` for synchronous logic
- Use `@(*)` for combinational logic
- Avoid incomplete sensitivity lists
- Initialize registers in `initial` blocks or reset logic

## State Machines
- Use `localparam` for state definitions
- Use enumerated names, not raw numbers
- Include default case in case statements

## Naming Conventions
- Modules: `module_name`
- Ports: `input_name`, `output_name`
- Wires: `wire_name`
- Regs: `reg_name`
- Parameters: `PARAM_NAME`
- Constants: `CONSTANT_NAME`

## Reset Logic
- Active-low reset: `rst_n`
- Synchronous reset preferred
- Initialize all registers

## Clock Domains
- Single clock domain unless necessary
- Use proper clock constraints
- Avoid clock gating

## Synthesis Considerations
- Avoid latches (incomplete if/case statements)
- Use blocking assignments (=) in combinational always
- Use non-blocking assignments (<=) in sequential always
- Pipeline for performance when needed

## File Organization
- One module per file
- Related modules in subdirectories
- Include files with `include
- Use relative paths

## Debugging
- Use `initial` blocks for simulation-only code
- Add debug signals to ports when needed
- Use meaningful names for testbenches

## Common Pitfalls to Avoid
- Multiple drivers on wires
- Race conditions
- Uninitialized registers
- Incorrect bit widths
- Missing resets

## XDC Constraints File Rules
- **CRITICAL:** When editing `.xdc` constraint files, you are ONLY allowed to:
  - Remove `#` to uncomment lines (enable constraints)
  - Add `#` to comment lines (disable constraints)
- **NO OTHER EDITS** are permitted to the XDC file
- Do NOT modify pin assignments, package pins, or any syntax
- Always use the original Basys3 template as the source of truth</content>
<parameter name="filePath">c:\Users\xiang\ee2026_Project\instructions.md
