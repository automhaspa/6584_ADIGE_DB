CREATE TABLE [dbo].[SottoComponenti]
(
[ID_COMPONENTE] [int] NOT NULL,
[ID_SOTTOCOMPONENTE] [int] NOT NULL,
[DESCRIZIONE] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[CODICE_ABBREVIATO] [varchar] (4) COLLATE Latin1_General_CI_AS NOT NULL,
[COLONNA] [int] NULL,
[PIANO] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SottoComponenti] ADD CONSTRAINT [PK_SottoComponenti] PRIMARY KEY CLUSTERED ([ID_SOTTOCOMPONENTE]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_SottoComponenti] ON [dbo].[SottoComponenti] ([ID_COMPONENTE], [CODICE_ABBREVIATO]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SottoComponenti] ADD CONSTRAINT [FK_SottoComponenti_Componenti] FOREIGN KEY ([ID_COMPONENTE]) REFERENCES [dbo].[Componenti] ([ID_COMPONENTE])
GO
