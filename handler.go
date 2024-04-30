package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path"
	"strconv"

	"github.com/Azure/azure-sdk-for-go/sdk/data/aztables"
)

const (
	TABLE_NAME            = "links"
	DEFAULT_PARTITION_KEY = "niels"
)

type LinkEntity struct {
	aztables.Entity
	URL      string `json:"Url"`
	Click    int32  `json:"Click"`
	MaxClick int32  `json:"MaxClick"`
}

func queryLink(client *aztables.Client, id string) (*LinkEntity, error) {
	resp, err := client.GetEntity(context.Background(), DEFAULT_PARTITION_KEY, id, nil)

	if err != nil {
		if err.Error() == "ResourceNotFound" {
			fmt.Println("Resource not found")
		} else {
			fmt.Println("Error")
			fmt.Println(err)
		}

		return nil, err
	}

	var myEntity LinkEntity
	err = json.Unmarshal(resp.Value, &myEntity)
	if err != nil {
		panic(err)
	}
	return &myEntity, nil
}

func updateLink(client *aztables.Client, link *LinkEntity) error {
	link.Click++

	data, err := json.Marshal(link)
	if err != nil {
		return err
	}

	_, err = client.UpsertEntity(context.Background(), data, nil)
	if err != nil {
		return err
	}

	return nil
}

func createLink(client *aztables.Client, id string, url string, maxClick int32) error {
	link := LinkEntity{
		Entity: aztables.Entity{
			PartitionKey: DEFAULT_PARTITION_KEY,
			RowKey:       id,
		},
		URL:      url,
		Click:    0,
		MaxClick: maxClick,
	}

	data, err := json.Marshal(link)
	if err != nil {
		return err
	}

	_, err = client.UpsertEntity(context.Background(), data, nil)
	if err != nil {
		return err
	}

	return nil
}

func handler(w http.ResponseWriter, r *http.Request) {
	cs := os.Getenv("CUSTOMCONNSTR_AzureStorageConnectionString")
	fmt.Println("cs: " + cs)

	serviceClient, err := aztables.NewServiceClientFromConnectionString(cs, nil)
	if err != nil {
		panic(err)
	}

	client := serviceClient.NewClient(TABLE_NAME)
	key := path.Base(r.URL.Path)

	if key != "url_shortener" {
		if r.Method == "GET" {
			link, _ := queryLink(client, key)
			if link != nil {
				if link.MaxClick != -1 && link.Click >= link.MaxClick {
					http.NotFound(w, r)
					return
				} else {
					updateLink(client, link)
					http.Redirect(w, r, link.URL, http.StatusPermanentRedirect)
				}
			} else {
				http.NotFound(w, r)
			}
		} else if r.Method == "POST" {
			link, _ := queryLink(client, key)
			if link == nil {
				url := r.URL.Query().Get("url")
				maxClick, err := strconv.Atoi(r.URL.Query().Get("max"))
				if err != nil {
					maxClick = -1
				}
				password := os.Getenv("PASSWORD")

				if url == "" || password == "" || r.URL.Query().Get("password") != password {
					w.WriteHeader(http.StatusBadRequest)
				} else {
					createLink(client, key, url, int32(maxClick))
					w.WriteHeader(http.StatusOK)
				}
			} else {
				w.WriteHeader(http.StatusConflict)
			}
		}
	}
}

func main() {
	listenAddr := ":8080"
	if val, ok := os.LookupEnv("FUNCTIONS_CUSTOMHANDLER_PORT"); ok {
		listenAddr = ":" + val
	}

	http.HandleFunc("/", handler)
	log.Printf("About to listen on %s. Go to https://127.0.0.1%s/", listenAddr, listenAddr)
	log.Fatal(http.ListenAndServe(listenAddr, nil))
}
