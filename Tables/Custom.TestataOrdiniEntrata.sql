CREATE TABLE [Custom].[TestataOrdiniEntrata]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[LOAD_ORDER_ID] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[LOAD_ORDER_TYPE] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL,
[DT_RECEIVE_BLM] [datetime] NOT NULL,
[SUPPLIER_CODE] [varchar] (10) COLLATE Latin1_General_CI_AS NOT NULL,
[DES_SUPPLIER_CODE] [varchar] (35) COLLATE Latin1_General_CI_AS NOT NULL,
[SUPPLIER_DDT_CODE] [varchar] (20) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Ddt_Fittizio] [int] NOT NULL,
[Stato] [int] NOT NULL CONSTRAINT [DF_TestataOrdiniEntrata_Stato] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[TestataOrdiniEntrata] ADD CONSTRAINT [PK__TestataO__3214EC275C13D258] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
