using Xamarin.Forms;
using System.Collections.Generic;
using System;

namespace MarixView
{

	public class DocumentViewTemplateSelector : DataTemplateSelector
	{
		public static bool IsLandscapeMode = false;

		public DataTemplate LandscapeTemplate { get; set; }
		public DataTemplate PortriatTemplate { get; set; }

		protected override DataTemplate OnSelectTemplate(object item, BindableObject container)
		{
			return IsLandscapeMode ? LandscapeTemplate : PortriatTemplate;
		}
	}

	public partial class MarixViewPage : ContentPage
	{
		public MarixViewPage()
		{
			InitializeComponent();

			if (Width > Height)
				DocumentViewTemplateSelector.IsLandscapeMode = true;
			else
				DocumentViewTemplateSelector.IsLandscapeMode = false;
			
			PrepareDocumentViewData(DocumentViewTemplateSelector.IsLandscapeMode);


		}

		void Handle_SizeChanged(object sender, System.EventArgs e)
		{
			if (Width > Height)
				DocumentViewTemplateSelector.IsLandscapeMode = true;
			else
				DocumentViewTemplateSelector.IsLandscapeMode = false;

			PrepareDocumentViewData(DocumentViewTemplateSelector.IsLandscapeMode);
		}

		void PrepareDocumentViewData(bool isLandscape)
		{
			IList<string> documents = new List<string>();

			for (int i = 0; i < 1000; i++)
			{
				documents.Add("Document_{0}" + i);
			}

			int rowWidth = isLandscape ? 5 : 3;
			DocumentModuleViewModel vm = new DocumentModuleViewModel(documents, rowWidth);
			documentListView.ItemsSource = vm.DocumentCollection;

			documentListView.RowHeight = 160;

			documentListView.Footer = new ContentView();
			
		}
	}
}
