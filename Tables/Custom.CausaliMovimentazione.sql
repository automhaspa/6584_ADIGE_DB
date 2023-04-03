CREATE TABLE [Custom].[CausaliMovimentazione]
(
[Id_Causale] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[Tipo_Causale] [varchar] (15) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione_Causale] [varchar] (150) COLLATE Latin1_General_CI_AS NULL,
[Action] [varchar] (1) COLLATE Latin1_General_CI_AS NULL,
[Attivo] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[CausaliMovimentazione] ADD CONSTRAINT [PK__CausaliM__C53B8EE5DACDE997] PRIMARY KEY CLUSTERED ([Id_Causale], [Tipo_Causale]) ON [PRIMARY]
GO
