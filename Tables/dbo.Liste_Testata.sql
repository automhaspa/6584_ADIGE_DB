CREATE TABLE [dbo].[Liste_Testata]
(
[Id_Gruppo_Lista] [int] NULL,
[Id_Lista] [int] NOT NULL IDENTITY(1, 1),
[Codice_Lista] [varchar] (30) COLLATE Latin1_General_CI_AS NOT NULL,
[Data_Lista] [datetime] NOT NULL CONSTRAINT [DF_Liste_Testata_Data_Lista] DEFAULT (getdate()),
[Priorita] [numeric] (4, 0) NULL CONSTRAINT [DF_Liste_Testata_Priorita] DEFAULT ((9999)),
[Id_Stato_Lista] [int] NOT NULL,
[Id_Tipo_Lista] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Liste_Testata] ADD CONSTRAINT [PK_Liste_Testata] PRIMARY KEY CLUSTERED ([Id_Lista]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Liste_Testata] ADD CONSTRAINT [FK_Liste_Testata_Lista_Host_Gruppi] FOREIGN KEY ([Id_Gruppo_Lista]) REFERENCES [dbo].[Lista_Host_Gruppi] ([Id_Gruppo_Lista])
GO
ALTER TABLE [dbo].[Liste_Testata] ADD CONSTRAINT [FK_Liste_Testata_Tipo_Lista] FOREIGN KEY ([Id_Tipo_Lista]) REFERENCES [dbo].[Tipo_Lista] ([Id_Tipo_Lista])
GO
ALTER TABLE [dbo].[Liste_Testata] ADD CONSTRAINT [FK_Liste_Testata_Tipo_Stati_Lista] FOREIGN KEY ([Id_Stato_Lista]) REFERENCES [dbo].[Tipo_Stati_Lista] ([Id_Stato_Lista])
GO
