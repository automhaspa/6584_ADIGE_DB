CREATE TABLE [Custom].[OrdineKittingBaia]
(
[Id_Testata_Lista] [int] NOT NULL,
[Id_Partizione] [int] NOT NULL,
[Kit_Id] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[OrdineKittingBaia] ADD CONSTRAINT [PK__OrdineKi__C01045EAC6436F4A] PRIMARY KEY CLUSTERED ([Id_Testata_Lista], [Id_Partizione], [Kit_Id]) ON [PRIMARY]
GO
