`timescale 1ns / 1ps

`include "ProgramCounter.v"
`include "ProgramCounterMUX.v"
`include "Adder.v"
`include "InstructionMemory.v"
`include "ControlUnit.v"
`include "ControlUnitMUX.v"
`include "RegisterModule.v"
`include "SignExtend.v"
`include "ALUControl.v"
`include "ALU.v"
`include "ShiftLeft2.v"
`include "DataMemory.v"
`include "ALUMux.v"
`include "DataMemoryMUX.v"
`include "RegisterMux.v"
`include "IFID.v"
`include "IDEX.v"
`include "EXMEM.v"
`include "MEMWB.v"
`include "ForwardingUnit.v"
`include "HazardDetectionUnit.v"
`include "ForwardingUnitALUMuxA.v"
`include "ForwardingUnitALUMuxB.v"


module ARMLEG (
	input CLOCK,
	input RESET
);

	// Datapath 
	wire reg2Loc;
	wire ALUsrc;
	wire memToReg;
	wire regWrite;
	wire memRead;
	wire memWrite;
	wire branch;
	wire zeroFlag;
	wire [63:0] adderResult;
	wire [31:0] CPUInstruction;
	wire [1:0] ALUop;
	wire [4:0] regMUX;
	wire [63:0] regData1;
	wire [63:0] regData2;
	wire [63:0] signExtendedResult;
	wire [3:0] ALUoperation;
	wire [63:0] ALUmux;
	wire [63:0] ALUresult;
	wire [63:0] shiftedResult;
	wire [63:0] branchAddress;
	wire [63:0] readData;
	wire [63:0] dataMemoryMUXresult;
	wire [63:0] programCounter_in;
	wire [63:0] programCounter_out;
	wire [10:0] ControlUnitMUXout;

	// IFID pipeline
	wire [63:0] IFID_ProgramCounter;
	wire [31:0] IFID_CPUInstruction;

	// IDEX pipeline
	wire [1:0] IDEX_ALUop; // EX Stage
	wire IDEX_ALUsrc; // EX Stage
	wire IDEX_isBranch; // M Stage
	wire IDEX_MemRead; // M Stage
	wire IDEX_MemWrite; // M Stage
	wire IDEX_RegWrite; // WB Stage
	wire IDEX_MemToReg; // WB Stage
	wire [63:0] IDEX_ProgramCounter;
	wire [63:0] IDEX_RegData1;
	wire [63:0] IDEX_RegData2;
	wire [63:0] IDEX_SignExtend;
	wire [10:0] IDEX_ALUcontrol;
	wire  [4:0] IDEX_WriteReg;
	wire  [4:0] IDEX_RegisterRm;
	wire  [4:0] IDEX_RegisterRn;

	// EXMEM pipeline
	wire EXMEM_MemRead; // M Stage
	wire EXMEM_MemWrite; // M Stage
	wire EXMEM_RegWrite; // WB Stage
	wire EXMEM_MemToReg; // WB Stage
	wire EXMEM_ALUzero; // Program Counter Mux
	wire EXMEM_isBranch; // M Stage		// Program Counter Mux
	wire [63:0] EXMEM_shiftedprogramCounter_out; // Program Counter Mux
	wire [63:0] EXMEM_InputAddress;
	wire [63:0] EXMEM_InputData;
	wire  [4:0] EXMEM_WriteReg;

	// MEMWB Pipeline
	wire [63:0] MEMWB_Address;
	wire [63:0] MEMWB_ReadData;
	wire  [4:0] MEMWB_WriteAddress;
	wire MEMWB_RegWrite;
	wire MEMWB_MemToReg;

	// Forwarding Unit
	wire [1:0] ForwardA;
	wire [1:0] ForwardB;
	wire [63:0] ForwardingUnitALUMUXoutA;
	wire [63:0] ForwardingUnitALUMUXoutB;

	// Hazard Detection unit
	wire IFID_Write;
	wire PCWire;
	wire ControlWire;

	// Hazard Detection unit
	// IFID_CPUInstruction[31:21] = Opcode
	// IFID_CPUInstruction[20:16] = RegisterRm
	// IFID_CPUInstruction[9:5] = RegisterRn
	// IFID_CPUInstruction[4:0] = RegisterRd or WriteReg or WriteAddress
	HazardDetectionUnit hazardDetectionUnit(IDEX_MemRead, EXMEM_RegWrite, IDEX_WriteReg, IFID_CPUInstruction[20:16], IFID_CPUInstruction[9:5], IFID_Write, PCWire, ControlWire);

	// Forwarding unit
	// IFID_CPUInstruction[20:16] = RegisterRm
	// IFID_CPUInstruction[9:5] = RegisterRn
	// IFID_CPUInstruction[4:0] = RegisterRd or WriteReg or WriteAddress
	ForwardingUnit forwardingUnit(IDEX_RegisterRm, IDEX_RegisterRn, EXMEM_WriteReg, MEMWB_WriteAddress, EXMEM_RegWrite, MEMWB_RegWrite, ForwardA, ForwardB);

	// Forwarding unit multiplexers
	ForwardingUnitALUMuxA forwardingUnitALUMuxA(IDEX_RegData1, dataMemoryMUXresult, EXMEM_InputAddress, ForwardA, ForwardingUnitALUMUXoutA);
	ForwardingUnitALUMuxB forwardingUnitALUMuxB(IDEX_RegData2, dataMemoryMUXresult, EXMEM_InputAddress, ForwardB, ForwardingUnitALUMUXoutB);

	ProgramCounter programCounter (CLOCK, RESET, PCWire, programCounter_in, programCounter_out);

	Adder fourAdder (64'b0100, programCounter_out, adderResult);

	ProgramCounterMUX programCounterMUX(adderResult, EXMEM_shiftedprogramCounter_out, (EXMEM_isBranch&EXMEM_ALUzero), programCounter_in);

	InstructionMemory instructionMemory(programCounter_out, CPUInstruction);

	// IFID stage
	IFID IFID (CLOCK, IFID_Write, programCounter_out, CPUInstruction,
		IFID_ProgramCounter, IFID_CPUInstruction
	);

	ControlUnitMUX controlUnitMUX(IFID_CPUInstruction[31:21], ControlWire, ControlUnitMUXout);

	ControlUnit controlUnit(ControlUnitMUXout, reg2Loc, ALUsrc, memToReg, regWrite, memRead, memWrite, branch, ALUop);

	RegisterMux registerMUX(IFID_CPUInstruction[20:16], IFID_CPUInstruction[4:0], reg2Loc, regMUX);

	RegisterModule registerModule(CLOCK, IFID_CPUInstruction[9:5], regMUX, MEMWB_WriteAddress, dataMemoryMUXresult, MEMWB_RegWrite, regData1, regData2);

	SignExtend signExtend(IFID_CPUInstruction, signExtendedResult);

	// IDEX stage
	IDEX IDEX(CLOCK, ALUop, ALUsrc, branch, memRead, memWrite, regWrite, memToReg, IFID_ProgramCounter, regData1, regData2, signExtendedResult, IFID_CPUInstruction[31:21], IFID_CPUInstruction[20:16], IFID_CPUInstruction[9:5], IFID_CPUInstruction[4:0],
		IDEX_ALUop, IDEX_ALUsrc, IDEX_isBranch, IDEX_MemRead, IDEX_MemWrite, IDEX_RegWrite, IDEX_MemToReg, IDEX_ProgramCounter, IDEX_RegData1, IDEX_RegData2, IDEX_SignExtend, IDEX_ALUcontrol, IDEX_RegisterRm, IDEX_RegisterRn, IDEX_WriteReg
	);

	ALUControl ALUcontrol(IDEX_ALUop, IDEX_ALUcontrol, ALUoperation);

	ALUMux ALUMUX(ForwardingUnitALUMUXoutB, IDEX_SignExtend, IDEX_ALUsrc, ALUmux);

	ALU ALU(ForwardingUnitALUMUXoutA, ALUmux, ALUoperation, ALUresult, zeroFlag);

	ShiftLeft2 shiftLeft2(IDEX_SignExtend, shiftedResult);

	Adder branchAdder(IDEX_ProgramCounter, shiftedResult,  branchAddress);

	// EXMEM stage
	EXMEM EXMEM(CLOCK, IDEX_isBranch, IDEX_MemRead, IDEX_MemWrite, IDEX_RegWrite, IDEX_MemToReg, branchAddress, zeroFlag, ALUresult, IDEX_RegData2, IDEX_WriteReg,
		EXMEM_isBranch, EXMEM_MemRead, EXMEM_MemWrite, EXMEM_RegWrite, EXMEM_MemToReg, EXMEM_shiftedprogramCounter_out, EXMEM_ALUzero, EXMEM_InputAddress, EXMEM_InputData, EXMEM_WriteReg
	);

	DataMemory dataMemory(CLOCK, EXMEM_InputAddress, EXMEM_InputData, EXMEM_MemRead, EXMEM_MemWrite, readData);

	// MEMWB stage
	MEMWB MEMWB(CLOCK, EXMEM_InputAddress, readData, EXMEM_WriteReg, EXMEM_RegWrite, EXMEM_MemToReg,
		MEMWB_Address, MEMWB_ReadData, MEMWB_WriteAddress, MEMWB_RegWrite, MEMWB_MemToReg
	);

	DataMemoryMUX dataMemoryMUX(MEMWB_ReadData, MEMWB_Address, MEMWB_MemToReg, dataMemoryMUXresult);
endmodule
