CREATE TABLE [dbo].[Lista_Uscita_Dettaglio]
(
[Id_Dettaglio] [int] NOT NULL,
[Qta_Prelevata] [numeric] (18, 4) NULL CONSTRAINT [DF_Table_1_QTA_PREL] DEFAULT ((0)),
[HORRNRIG] [varchar] (7) COLLATE Latin1_General_CI_AS NULL,
[HORRIDCOMR] [int] NULL,
[UM] [varchar] (2) COLLATE Latin1_General_CI_AS NULL,
[Lotto] [varchar] (20) COLLATE Latin1_General_CI_AS NULL,
[Customer] [varchar] (10) COLLATE Latin1_General_CI_AS NULL,
[DeliveryType] [varchar] (2) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lista_Uscita_Dettaglio] ADD CONSTRAINT [PK_Lista_Uscita_Dettaglio] PRIMARY KEY CLUSTERED ([Id_Dettaglio]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lista_Uscita_Dettaglio] ADD CONSTRAINT [FK_Lista_Uscita_Dettaglio_Liste_Dettaglio] FOREIGN KEY ([Id_Dettaglio]) REFERENCES [dbo].[Liste_Dettaglio] ([Id_Dettaglio])
GO
