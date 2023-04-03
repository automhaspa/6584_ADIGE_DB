CREATE TABLE [Custom].[AnagraficaMancanti]
(
[Id_Testata] [int] NOT NULL,
[Id_Riga] [int] NOT NULL,
[Id_Articolo] [int] NOT NULL,
[Qta_Mancante] [numeric] (10, 2) NOT NULL CONSTRAINT [DF__Anagrafic__Qta_Manc__2C738AF2] DEFAULT ((0)),
[WBS_Riferimento] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[COMM_PROD] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[COMM_SALE] [varchar] (25) COLLATE Latin1_General_CI_AS NULL,
[PROD_ORDER] [varchar] (20) COLLATE Latin1_General_CI_AS NULL,
[SAP_DOC_NUM] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[PROD_LINE] [varchar] (80) COLLATE Latin1_General_CI_AS NULL,
[RagSoc_Dest] [char] (10) COLLATE Latin1_General_CI_AS NULL,
[ORDER_ID] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[ORDER_TYPE] [varchar] (4) COLLATE Latin1_General_CI_AS NULL,
[DT_EVASIONE] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AnagraficaMancanti] ADD CONSTRAINT [PK__AnagraficaMancanti] PRIMARY KEY CLUSTERED ([Id_Testata], [Id_Riga]) ON [PRIMARY]
GO
