CREATE TABLE [Custom].[RigheOrdiniEntrata]
(
[Id_Testata] [int] NOT NULL,
[LOAD_LINE_ID] [int] NOT NULL,
[ITEM_CODE] [varchar] (18) COLLATE Latin1_General_CI_AS NOT NULL,
[LINE_ID_ERP] [numeric] (6, 0) NULL,
[QUANTITY] [numeric] (10, 3) NULL,
[PURCHASE_ORDER_ID] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[FL_INDEX_ALIGN] [int] NOT NULL,
[FL_QUALITY_CHECK] [int] NOT NULL,
[COMM_PROD] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[COMM_SALE] [varchar] (24) COLLATE Latin1_General_CI_AS NULL,
[SUB_LOAD_ORDER_TYPE] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[MANUFACTURER_ITEM] [varchar] (35) COLLATE Latin1_General_CI_AS NULL,
[MANUFACTURER_NAME] [varchar] (35) COLLATE Latin1_General_CI_AS NULL,
[DOC_NUMBER] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[REF_NUMBER] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[NOTES] [varchar] (140) COLLATE Latin1_General_CI_AS NULL,
[CONTROL_LOT] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[Stato] [int] NOT NULL CONSTRAINT [DF_RigheOrdiniEntrata_Stato] DEFAULT ((1)),
[WBS_ELEM] [varchar] (40) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[RigheOrdiniEntrata] ADD CONSTRAINT [PK__RigheOrd__99D3A90702733583] PRIMARY KEY CLUSTERED ([Id_Testata], [LOAD_LINE_ID], [ITEM_CODE]) ON [PRIMARY]
GO
