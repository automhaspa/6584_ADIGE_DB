CREATE TABLE [Custom].[RigheListePrelievo]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Id_Testata] [int] NULL,
[LINE_ID] [int] NOT NULL,
[LINE_ID_ERP] [numeric] (6, 0) NULL,
[ITEM_CODE] [varchar] (18) COLLATE Latin1_General_CI_AS NOT NULL,
[PROD_ORDER] [varchar] (20) COLLATE Latin1_General_CI_AS NOT NULL,
[QUANTITY] [numeric] (10, 3) NOT NULL,
[COMM_PROD] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[COMM_SALE] [varchar] (25) COLLATE Latin1_General_CI_AS NULL,
[PROD_LINE] [varchar] (80) COLLATE Latin1_General_CI_AS NULL,
[DOC_NUMBER] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[SAP_DOC_NUM] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[RETURN_DATE] [date] NULL,
[KIT_ID] [int] NULL,
[Stato] [int] NULL,
[RSPOS] [numeric] (4, 0) NULL,
[WBS_Riferimento] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[Vincolo_WBS] [bit] NULL,
[Magazzino] [varchar] (4) COLLATE Latin1_General_CI_AS NULL,
[Motivo_Nc] [varchar] (25) COLLATE Latin1_General_CI_AS NULL,
[BEHMG] [numeric] (10, 3) NULL,
[PKBHT] [varchar] (15) COLLATE Latin1_General_CI_AS NULL,
[ABLAD] [varchar] (10) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[RigheListePrelievo] ADD CONSTRAINT [PK__RigheLis__3214EC276B63A429] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[RigheListePrelievo] ADD CONSTRAINT [FkRigheListePrelievo_Id_Testata] FOREIGN KEY ([Id_Testata]) REFERENCES [Custom].[TestataListePrelievo] ([ID])
GO
