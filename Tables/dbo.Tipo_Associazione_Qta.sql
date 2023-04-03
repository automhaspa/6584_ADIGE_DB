CREATE TABLE [dbo].[Tipo_Associazione_Qta]
(
[Id_Associazione_Qta] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Indice_Ricerca] [int] NOT NULL,
[Ordine_Visualizzazione] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Associazione_Qta] ADD CONSTRAINT [PK_Tipo_Associazione_Qta] PRIMARY KEY CLUSTERED ([Id_Associazione_Qta]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [Indice_Ricerca] ON [dbo].[Tipo_Associazione_Qta] ([Indice_Ricerca]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Colonna chiave da inserire nella testata delle Udc per specificare il suo livello di ricerca per la simulazione.  ', 'SCHEMA', N'dbo', 'TABLE', N'Tipo_Associazione_Qta', 'COLUMN', N'Id_Associazione_Qta'
GO
EXEC sp_addextendedproperty N'MS_Description', N'serve per capire l''ordine di ricerca nella sp_Insert_Simulazione.', 'SCHEMA', N'dbo', 'TABLE', N'Tipo_Associazione_Qta', 'COLUMN', N'Indice_Ricerca'
GO
