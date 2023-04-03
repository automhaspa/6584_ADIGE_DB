CREATE TABLE [Custom].[Tipo_Stato_Testata_ListePrelievo]
(
[Id_Stato_Testata] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Stato_Testata_ListePrelievo] ADD CONSTRAINT [PK__Tipo_Sta__1076DFFA52A2D3C5] PRIMARY KEY CLUSTERED ([Id_Stato_Testata]) ON [PRIMARY]
GO
