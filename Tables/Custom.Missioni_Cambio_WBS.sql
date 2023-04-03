CREATE TABLE [Custom].[Missioni_Cambio_WBS]
(
[Id_Udc] [numeric] (18, 0) NOT NULL,
[Id_UdcDettaglio] [int] NOT NULL,
[Id_Cambio_WBS] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL,
[Quantita] [numeric] (18, 2) NOT NULL,
[Qta_Spostata] [numeric] (10, 2) NULL,
[Id_Stato_Lista] [int] NOT NULL,
[Id_Missione] [int] NULL,
[DataOra_Creazione] [datetime] NOT NULL,
[DataOra_UltimaModifica] [datetime] NOT NULL,
[DataOra_Esecuzione] [datetime] NULL,
[DataOra_Termine] [datetime] NULL,
[Descrizione] [varchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [PK_Missioni_Picking_Dettaglio] PRIMARY KEY CLUSTERED ([Id_Udc], [Id_UdcDettaglio], [Id_Cambio_WBS]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [FK_Missioni_Cambio_WBS_Articoli] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [FK_Missioni_Cambio_WBS_Id_Cambio_Wbs] FOREIGN KEY ([Id_Cambio_WBS]) REFERENCES [Custom].[CambioCommessaWBS] ([ID])
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [FK_Missioni_Cambio_WBS_Tipo_Stati_Lista] FOREIGN KEY ([Id_Stato_Lista]) REFERENCES [dbo].[Tipo_Stati_Lista] ([Id_Stato_Lista])
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [FK_Missioni_Cambio_WBS_UDC] FOREIGN KEY ([Id_Udc]) REFERENCES [dbo].[Udc_Testata] ([Id_Udc])
GO
ALTER TABLE [Custom].[Missioni_Cambio_WBS] ADD CONSTRAINT [FK_Missioni_Cambio_WBS_Udc_Dettaglio] FOREIGN KEY ([Id_UdcDettaglio]) REFERENCES [dbo].[Udc_Dettaglio] ([Id_UdcDettaglio])
GO
