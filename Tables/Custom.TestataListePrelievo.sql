CREATE TABLE [Custom].[TestataListePrelievo]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ORDER_ID] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[ORDER_TYPE] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[DT_EVASIONE] [date] NOT NULL,
[COMM_PROD] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[COMM_SALE] [varchar] (25) COLLATE Latin1_General_CI_AS NULL,
[DES_PREL_CONF] [varchar] (512) COLLATE Latin1_General_CI_AS NULL,
[ITEM_CODE_FIN] [varchar] (13) COLLATE Latin1_General_CI_AS NULL,
[FL_KIT] [bit] NOT NULL,
[NR_KIT] [int] NULL,
[PRIORITY] [int] NOT NULL,
[PROD_LINE] [varchar] (80) COLLATE Latin1_General_CI_AS NULL,
[SUB_ORDER_TYPE] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[RAD] [varchar] (6) COLLATE Latin1_General_CI_AS NULL,
[PFIN] [varchar] (30) COLLATE Latin1_General_CI_AS NULL,
[DETT_ETI] [varchar] (275) COLLATE Latin1_General_CI_AS NULL,
[FL_LABEL] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[FL_KIT_CALC] [int] NOT NULL,
[Stato] [int] NOT NULL CONSTRAINT [DF__TestataLi__Stato__64ECEE3F] DEFAULT ((1)),
[DataOraCreazioneRecord] [datetime] NOT NULL CONSTRAINT [DF__TestataLi__DataO__65E11278] DEFAULT (getdate()),
[Id_Partizione_Uscita] [int] NULL,
[APERTURA_MANCANTI] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[TestataListePrelievo] ADD CONSTRAINT [PK__TestataL__3214EC2775AAEBFC] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
