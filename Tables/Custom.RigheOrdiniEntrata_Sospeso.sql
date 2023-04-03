CREATE TABLE [Custom].[RigheOrdiniEntrata_Sospeso]
(
[Id_Testata] [int] NOT NULL,
[LOAD_LINE_ID] [int] NOT NULL,
[ITEM_CODE] [varchar] (18) COLLATE Latin1_General_CI_AS NOT NULL,
[PURCHASE_ORDER_ID] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[QTA_TOTALE] [numeric] (18, 4) NOT NULL,
[QTA_DA_CONSUNTIVARE] [numeric] (18, 4) NOT NULL,
[QTA_DA_STORNARE] [numeric] (18, 4) NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[RigheOrdiniEntrata_Sospeso] ADD CONSTRAINT [PK__RigheOrdSospeso] PRIMARY KEY CLUSTERED ([Id_Testata], [LOAD_LINE_ID], [ITEM_CODE]) ON [PRIMARY]
GO
