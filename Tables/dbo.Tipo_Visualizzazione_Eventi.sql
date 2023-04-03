CREATE TABLE [dbo].[Tipo_Visualizzazione_Eventi]
(
[Id_Tipo_Visualizzazione_Evento] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (250) COLLATE Latin1_General_CI_AS NULL,
[UserControl] [varchar] (150) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Visualizzazione_Eventi] ADD CONSTRAINT [PK_Tipo_Visualizzazione_Eventi] PRIMARY KEY CLUSTERED ([Id_Tipo_Visualizzazione_Evento]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Elemento personalizzato di visualizzazione.', 'SCHEMA', N'dbo', 'TABLE', N'Tipo_Visualizzazione_Eventi', 'COLUMN', N'Id_Tipo_Visualizzazione_Evento'
GO
