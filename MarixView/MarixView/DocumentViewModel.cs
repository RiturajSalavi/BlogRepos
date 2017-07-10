using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Collections.ObjectModel;

namespace MarixView
{
    public class DocumentItemViewModel:ViewModelBase
    {
        private string name;
        public string Name
        {
            get { return name; }
            set { SetProperty(ref name, value); }
        }
        private string icon;
        public string Icon
        {
            get { return icon; }
            set { SetProperty(ref icon, value); }
        }
		private bool isNotDummy;
        public bool IsNotDummy
		{
			get { return isNotDummy; }
			set { SetProperty(ref isNotDummy, value); }
		}

		public DocumentItemViewModel()
		{
			isNotDummy = true;
		}
    }

    public class DocumentViewRowViewModel : ViewModelBase
    {
        private int rowNumber;
        public int RowNumber
        {
            get { return rowNumber; }
            set { SetProperty(ref rowNumber, value); }
        }

        private ObservableCollection<DocumentItemViewModel> documentViewRowCollection;
        public  ObservableCollection<DocumentItemViewModel> DocumentViewRowCollection
        {
            get { return documentViewRowCollection; }
            set { SetProperty(ref documentViewRowCollection, value); }
        }

		public DocumentViewRowViewModel()
		{
			documentViewRowCollection = new ObservableCollection<DocumentItemViewModel>();
		}
    }

    public class DocumentModuleViewModel: ViewModelBase
    {
        private ObservableCollection<DocumentViewRowViewModel> documentCollection;
        public ObservableCollection<DocumentViewRowViewModel> DocumentCollection
        {
            get { return documentCollection; }
            set { SetProperty(ref documentCollection, value); }
        }
        public DocumentModuleViewModel(IList<String> documentItems, int rowWidth)
        {
			documentCollection = new ObservableCollection<DocumentViewRowViewModel>();
            int index = 0;
            DocumentViewRowViewModel documentRow = new DocumentViewRowViewModel();
            foreach (var document in documentItems)
            {
                if(index == 0)
                {
                    documentRow = new DocumentViewRowViewModel();
                }

                documentRow.DocumentViewRowCollection.Add( new DocumentItemViewModel() { Name= document});
                index++;

                if(index == rowWidth)
                {
                    documentCollection.Add(documentRow);
                    index = 0;
                }                
            }

			if (index != 0 && documentRow.DocumentViewRowCollection.Count > 0)
			{
				int dummyCount = rowWidth - documentRow.DocumentViewRowCollection.Count;

				for (int i = 0; i < dummyCount; i++)
				{
					documentRow.DocumentViewRowCollection.Add(new DocumentItemViewModel() { IsNotDummy = false });
				}
 
				documentCollection.Add(documentRow);
			}
        }

    }
}
