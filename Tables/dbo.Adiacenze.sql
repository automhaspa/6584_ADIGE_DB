CREATE TABLE [dbo].[Adiacenze]
(
[Id_Adiacenza] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (80) COLLATE Latin1_General_CI_AS NULL,
[Id_Partizione_Sorgente] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NOT NULL,
[Id_Tipo_Messaggio] [varchar] (5) COLLATE Latin1_General_CI_AS NULL,
[Peso] [int] NULL,
[Abilitazione] [bit] NULL,
[Direzione] [varchar] (1) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze] ADD CONSTRAINT [PK_Adiacenze] PRIMARY KEY CLUSTERED ([Id_Adiacenza]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Partizioni] ON [dbo].[Adiacenze] ([Id_Partizione_Sorgente], [Id_Partizione_Destinazione], [Id_Tipo_Messaggio]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze] ADD CONSTRAINT [FK_Adiacenze_Partizioni] FOREIGN KEY ([Id_Partizione_Sorgente]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Adiacenze] ADD CONSTRAINT [FK_Adiacenze_Partizioni1] FOREIGN KEY ([Id_Partizione_Destinazione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Adiacenze] ADD CONSTRAINT [FK_Adiacenze_Tipo_Messaggi] FOREIGN KEY ([Id_Tipo_Messaggio]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
