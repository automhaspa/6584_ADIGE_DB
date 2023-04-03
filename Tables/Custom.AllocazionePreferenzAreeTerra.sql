CREATE TABLE [Custom].[AllocazionePreferenzAreeTerra]
(
[Id_Partizione] [int] NOT NULL,
[Id_Articolo] [numeric] (18, 0) NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AllocazionePreferenzAreeTerra] ADD CONSTRAINT [PK__Allocazi__D3D4ACC573D2F19A] PRIMARY KEY CLUSTERED ([Id_Partizione], [Id_Articolo]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AllocazionePreferenzAreeTerra] ADD CONSTRAINT [FK__Allocazio__Id_Ar__0A3E6E7F] FOREIGN KEY ([Id_Articolo]) REFERENCES [dbo].[Articoli] ([Id_Articolo])
GO
ALTER TABLE [Custom].[AllocazionePreferenzAreeTerra] ADD CONSTRAINT [FK__Allocazio__Id_Pa__094A4A46] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE]) ON UPDATE CASCADE
GO
