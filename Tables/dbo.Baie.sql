CREATE TABLE [dbo].[Baie]
(
[Id_Partizione] [int] NOT NULL,
[Descrizione] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Pc] [int] NOT NULL,
[Tipo_Orientamento_Udc] [nchar] (3) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [DF_Baie_Tipo_Orientamento_Udc_1] DEFAULT (N'vbx')
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Baie] ADD CONSTRAINT [PK_Baie] PRIMARY KEY CLUSTERED ([Id_Partizione], [Id_Pc]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Baie] ADD CONSTRAINT [FK_Baie_Partizioni] FOREIGN KEY ([Id_Partizione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Baie] ADD CONSTRAINT [FK_Baie_Pc] FOREIGN KEY ([Id_Pc]) REFERENCES [dbo].[Pc] ([Id_Pc])
GO
ALTER TABLE [dbo].[Baie] ADD CONSTRAINT [FK_Baie_Tipo_Orientamento_Udc] FOREIGN KEY ([Tipo_Orientamento_Udc]) REFERENCES [dbo].[Tipo_Orientamento_Udc] ([Id_Tipo_Orientamento_Cassetto])
GO
