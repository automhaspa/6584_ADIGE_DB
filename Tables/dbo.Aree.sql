CREATE TABLE [dbo].[Aree]
(
[ID_AREA] [int] NOT NULL,
[DESCRIZIONE] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[CODICE_ABBREVIATO] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Aree] ADD CONSTRAINT [PK_Aree_1] PRIMARY KEY CLUSTERED ([ID_AREA]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Identificativo univoco dello stabilimento.', 'SCHEMA', N'dbo', 'TABLE', N'Aree', 'COLUMN', N'ID_AREA'
GO
