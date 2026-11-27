localparam [2:0] INST_NOP = 3'd0;
localparam [2:0] INST_LDA = 3'd1;
localparam [2:0] INST_STA = 3'd2;
localparam [2:0] INST_CLC = 3'd3;
localparam [2:0] INST_ADC = 3'd4;
localparam [2:0] INST_JMP = 3'd5;

localparam [1:0] MODE_IMP = 2'd0;
localparam [1:0] MODE_IMM = 2'd1;
localparam [1:0] MODE_ABS = 2'd2;

localparam [2:0] STARTING = 3'd0;
localparam [2:0] OPCODE   = 3'd1;
localparam [2:0] OPERAND  = 3'd2;
localparam [2:0] HIGH     = 3'd3;
localparam [2:0] STORE    = 3'd4;
