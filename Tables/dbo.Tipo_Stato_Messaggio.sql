CREATE TABLE [dbo].[Tipo_Stato_Messaggio]
(
[Id_Tipo_Stato_Messaggio] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (20) COLLATE Latin1_General_CI_AS NULL,
[Descrizione_Abbreviata] [varchar] (3) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Stato_Messaggio] ADD CONSTRAINT [PK_Tipo_Stato_Messaggio] PRIMARY KEY CLUSTERED ([Id_Tipo_Stato_Messaggio]) ON [PRIMARY]
GO
