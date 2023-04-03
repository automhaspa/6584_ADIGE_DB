CREATE TABLE [Custom].[CambioCommessaWBS]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Load_Order_Id] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[Load_Order_Type] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Articolo] [numeric] (18, 0) NULL,
[WBS_Partenza] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[WBS_Destinazione] [varchar] (40) COLLATE Latin1_General_CI_AS NULL,
[Id_Stato_Lista] [int] NOT NULL,
[Qta_Pezzi] [int] NOT NULL,
[DataOra_Creazione] [datetime] NOT NULL,
[DataOra_UltimaModifica] [datetime] NOT NULL,
[DataOra_Avvio] [datetime] NULL,
[DataOra_Chiusura] [datetime] NULL,
[Descrizione] [varchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[CambioCommessaWBS] ADD CONSTRAINT [PK_CambioWbs] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[CambioCommessaWBS] ADD CONSTRAINT [FK_CambioCommessaWBS_Tipo_Stati_Lista] FOREIGN KEY ([Id_Stato_Lista]) REFERENCES [dbo].[Tipo_Stati_Lista] ([Id_Stato_Lista])
GO
ALTER TABLE [Custom].[CambioCommessaWBS] ADD CONSTRAINT [FK_CambioWbs_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
