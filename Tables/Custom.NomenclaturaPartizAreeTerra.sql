CREATE TABLE [Custom].[NomenclaturaPartizAreeTerra]
(
[Id_Partizione] [int] NOT NULL,
[Codice_Sottoarea] [varchar] (100) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[NomenclaturaPartizAreeTerra] ADD CONSTRAINT [PK__Nomencla__D3D4ACC5F47D84F7] PRIMARY KEY CLUSTERED ([Id_Partizione]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[NomenclaturaPartizAreeTerra] ADD CONSTRAINT [FK__Nomenclat__Id_Pa__23FE4082] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
