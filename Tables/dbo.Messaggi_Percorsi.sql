CREATE TABLE [dbo].[Messaggi_Percorsi]
(
[Id_Messaggio] [int] NOT NULL,
[Id_Percorso] [int] NOT NULL,
[Sequenza_Percorso] [int] NOT NULL,
[Id_Udc] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Messaggi_Percorsi] ADD CONSTRAINT [PK_Messaggi_Percorsi] PRIMARY KEY CLUSTERED ([Id_Messaggio], [Id_Percorso]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Messaggi_Percorsi] ADD CONSTRAINT [FK_Messaggi_Percorsi_Messaggi_Inviati] FOREIGN KEY ([Id_Messaggio]) REFERENCES [dbo].[Messaggi_Inviati] ([ID_MESSAGGIO])
GO
ALTER TABLE [dbo].[Messaggi_Percorsi] ADD CONSTRAINT [FK_Messaggi_Percorsi_Percorso1] FOREIGN KEY ([Id_Percorso], [Sequenza_Percorso]) REFERENCES [dbo].[Percorso] ([Id_Percorso], [Sequenza_Percorso])
GO
