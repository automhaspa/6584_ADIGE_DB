CREATE TABLE [Custom].[NomenclaturaSottoCompAreeTerra]
(
[Id_Sottocomponente] [int] NOT NULL,
[Codice_Area] [varchar] (30) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[NomenclaturaSottoCompAreeTerra] ADD CONSTRAINT [PK__Nomencla__1B755539E9D31975] PRIMARY KEY CLUSTERED ([Id_Sottocomponente]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[NomenclaturaSottoCompAreeTerra] ADD CONSTRAINT [FK__Nomenclat__Id_So__029D4CB7] FOREIGN KEY ([Id_Sottocomponente]) REFERENCES [dbo].[SottoComponenti] ([ID_SOTTOCOMPONENTE]) ON UPDATE CASCADE
GO
